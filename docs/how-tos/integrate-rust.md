# Integrate with Rust

## Preface

This guide will explain how to delegate authorization decisions to OPA from a Rust application via the [OPA REST API](https://www.openpolicyagent.org/docs/latest/rest-api/).

!!! note

    This guide assumes you have deployed an OPA instance with a system package as described in the [policy writing guide](write-policy.md) - see the [Helm](deploy-with-helm.md) or [docker-compose](deploy-docker-compose.md) deployment guide for instructions on OPA deployment.


## Dependencies

We will use the following dependencies:

- [`tokio`](https://docs.rs/tokio/) to provide an async runtime - with the `macros` feature allowing us to easily async-ify the main function
- [`serde`](https://docs.rs/serde/) to provide struct and enum (de)serialization - with the `derive` feature allowing us to derive the `Serialize` and `Deserialize` traits for our enums and structs.
- [`reqwest`](https://docs.rs/reqwest) as our HTTP client - with the `json` feature allowing us to easily serialize and deserialize the HTTP bodies using `serde`.

!!! example

    **`Cargo.toml`**
    ```toml
    [dependencies]
    reqwest = { version = "0.11.27", features = ["json"] }
    serde = { version = "1.0.197", features = ["derive"] }
    tokio = { version = "1.37.0", features = ["macros"] }
    ```

## Runtime

In this guide, we will use a tokio runtime, this can be created using the `#[tokio::main]` macro on an asynchronous main function. The `"current_thread"` flavour specifies that a single-threaded runtime will be created, omission will make this multi-threaded, but requires the `tokio` `rt-multi-thread` feature.

```rust
#[tokio::main(flavor = "current_thread")]
async fn main() {}
```

## Serializing Input Data

OPA expects a JSON object as it's input, with the exact fields depending on the policy being involked - we will assume our policy requires a `subject` name, an `action` which is either `"read"` or `"write"` and an `item_id`. This can be therefore represented as the struct `Input`, which consists of the required fields - where the `action` is represented by the `Action` enum. The `serde::Serialize` [derive macro](https://doc.rust-lang.org/reference/procedural-macros.html#derive-macros) is used to implement this trivial serialization strategy. 

```rust
#[derive(Debug, serde::Serialize)]
enum Action {
    #[serde(rename = "read")]
    Read,
    #[serde(rename = "write")]
    Write,
}

#[derive(Debug, serde::Serialize)]
struct Input {
    subject: String,
    action: Action,
    item_id: u32,
}
```

We can now create an instance of this input as so:

```rust
let input = Input {
    subject: "bob".to_string(),
    action: Action::Read,
    item_id: 42,
};
```

## Making the Request

We will use `reqwest` to `POST` to the opa root path - shown henceforth as `http://opa:8181/`. To do this we create a `reqwest::Client` and call the `post` method with the OPA root query URL; we will pass the input as `json` before `send`ing and asynchronously `await`ing the response. We will unwind the stack if an error is encountered using `unwrap`.

```rust
let client = reqwest::Client::new();
let response = client
    .post("http://opa:8181/")
    .json(&input)
    .send()
    .await
    .unwrap();
```

## Interpreting the Decision

OPA returns a decision as a JSON object, with the exact fields depending on the policy being involked - we will assume our policy returns only an `allow` boolean. This can therefore be represented as the struct `Decision`, which contains the `allow` field. The `serde::Deserialize` [derive macro](https://doc.rust-lang.org/reference/procedural-macros.html#derive-macros) is used to implement this trivial deserialization strategy.

```rust
#[derive(Debug, serde::Deserialize)]
struct Decision {
    allow: bool,
}
```

We can now deserialize the response of OPA using the `json` method on the response with the target type:

```rust
let decision = response.json::<Decision>().await.unwrap();
```

Finally, we can access the `allow` field of the `decision` and print it to stdout:

```rust
println!("Allowed: {}", decision.allow);
```

!!! example "Complete Code"

    ```rust
    #[derive(Debug, serde::Serialize)]
    enum Action {
        #[serde(rename = "read")]
        Read,
        #[serde(rename = "write")]
        Write,
    }

    #[derive(Debug, serde::Serialize)]
    struct Input {
        subject: String,
        action: Action,
        item_id: u32,
    }

    #[derive(Debug, serde::Deserialize)]
    struct Decision {
        allow: bool,
    }

    #[tokio::main(flavor = "current_thread")]
    async fn main() {
        let input = Input {
            subject: "bob".to_string(),
            action: Action::Read,
            item_id: 42,
        };

        let client = reqwest::Client::new();
        let response = client
            .post("http://opa:8181/")
            .json(&input)
            .send()
            .await
            .unwrap();

        let decision = response.json::<Decision>().await.unwrap();
        println!("Allowed: {}", decision.allow);
    }
    ```
