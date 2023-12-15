use axum::{
    extract::Request,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use headers::{authorization::Bearer, Authorization, HeaderMapExt};
use std::{
    future::Future,
    pin::Pin,
    task::{Context, Poll},
};
use tower::{Layer, Service};

/// A [`tower::Layer`] which checks for a correct Authorization Bearer token
///
/// Requests which do not have a valid token are sent a 401 Unauthorized response
#[derive(Clone)]
pub struct RequireBearerLayer {
    /// The required token value
    required_token: Option<String>,
}

impl RequireBearerLayer {
    /// Creates the [`tower::Layer`] with a given required token
    pub fn new(required_token: Option<String>) -> Self {
        Self { required_token }
    }
}

impl<S> Layer<S> for RequireBearerLayer {
    type Service = RequireBearerMiddleware<S>;

    fn layer(&self, inner: S) -> Self::Service {
        RequireBearerMiddleware {
            inner,
            required_token: self.required_token.clone(),
        }
    }
}

/// A [`tower::Service`] which checks for a correct Authorization Bearer token
///
/// Requests which do not have a valid token are sent a 401 Unauthorized response
#[derive(Clone)]
pub struct RequireBearerMiddleware<S> {
    /// The wrapped [`Service`]
    inner: S,
    /// The required token value
    required_token: Option<String>,
}

impl<S> Service<Request> for RequireBearerMiddleware<S>
where
    S: Service<Request, Response = Response> + Send + 'static,
    S::Future: Send + 'static,
{
    type Response = S::Response;
    type Error = S::Error;
    type Future =
        Pin<Box<dyn Future<Output = Result<Self::Response, Self::Error>> + Send + 'static>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, request: Request) -> Self::Future {
        let valid_token = match (
            self.required_token.as_ref(),
            request.headers().typed_get::<Authorization<Bearer>>(),
        ) {
            (Some(required_token), Some(bearer_token)) => required_token == bearer_token.token(),
            (Some(_), None) => false,
            (None, _) => true,
        };

        let future = self.inner.call(request);

        Box::pin(async move {
            if valid_token {
                Ok(future.await?)
            } else {
                Ok(StatusCode::UNAUTHORIZED.into_response())
            }
        })
    }
}
