# Integrate with Python

## Preface

This guide will explain how to delegate authorization decisions to OPA from a Python application via the [OPA REST API](https://www.openpolicyagent.org/docs/latest/rest-api/).

!!! note

    This guide assumes you have deployed an OPA instance with a system package as described in the [policy writing guide](write-policy.md) - see the [Helm](deploy-with-helm.md) or [docker-compose](deploy-docker-compose.md) deployment guide for instructions on OPA deployment.

## Dependencies

We will use the following dependencies:

- [`requests`](https://pypi.org/project/requests/) as our HTTP client.
- [`pydantic`](https://pypi.org/project/pydantic/) to provide type safe struct and enum (de)serialization.

!!! example

    ```toml title="pyproject.toml"
    [project]
    dependencies = [
        "requests==2.31.0",
        "pydantic==2.6.4"
    ]
    ```

## Serializing Input Data

OPA expects a JSON object as it's input, with the exact fields depending on the policy being involked - we will assume our policy requires a `subject` name, an `action` which is either `"read"` or `"write"` and an `item_id`. This can therefore be represented as a `pydatnic` `BaseModel` which consists of the required fields - where the `action` is represented by the `Action` `Enum`.

```python
from enum import Enum
from pydantic import BaseModel


class Action(Enum):
    Read = "read"
    Write = "write"


class Input(BaseModel):
    subject: str
    action: Action
    item_id: int
```

We can now create an instance of this input as so:

```python
opa_input = Input(subject="bob", action=Action.Read, item_id=42)
```

## Making the Request

We will use `requests` to `POST` to the opa root path - shown henceforth as `http://opa:8181/`. To do this we will simply call `requests.post` with the OPA root query URL; we will serialize the input as json using the `model_dump_json` method and pass it to the optional `body` argument.

```python
response = requests.post("http://opa:8181/", data=opa_input.model_dump_json())
```

!!! note

    We are assuming the response will be `OK` (`200`). In a real application, you should check the `response.code` and handle such cases appropriately.

## Interpreting the Decision

OPA returns a decision as a JSON object, with the exact fields depending on the policy being involked - we will assume our policy returns only an `allow` boolean. This can therefore be represented as the `pydantic` `BaseModel` `Decision`, which contains the `allow` field.

```python
class Decision(BaseModel):
    allow: bool
```

We can now deserialize the response of OPA using the `model_validate_json` method on the `Decision` class with the `response` `text` as the argument:

```python
decision = Decision.model_validate_json(response.text)
```

Finally, we can access the `allow` field of the `decision` and print it to stdout:

```python
print(f"Allowed: {decision.allow}")
```

!!! example "Complete Code"

    ```python
    import requests
    from enum import Enum
    from pydantic import BaseModel


    class Action(Enum):
        Read = "read"
        Write = "write"


    class Input(BaseModel):
        subject: str
        action: Action
        item_id: int


    class Decision(BaseModel):
        allow: bool


    if __name__ == "__main__":
        opa_input = Input(subject="bob", action=Action.Read, item_id=42)

        response = requests.post("http://opa:8181/", data=opa_input.model_dump_json())

        decision = Decision.model_validate_json(response.text)
        print(f"Allowed: {decision.allow}")
    ```
