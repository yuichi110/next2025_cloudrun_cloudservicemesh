import os
import socket

from fastapi import FastAPI, HTTPException, Request
import httpx
import uvicorn

PORT = int(os.environ.get("PORT", 8080))
APP_NAME = os.environ.get("K_SERVICE", "CLIENT")

app = FastAPI()


@app.get("/")
async def hello():
    """
    Returns a simple greeting message.
    """
    return {"message": APP_NAME}


@app.get("/call/{target_hostname}")
async def call_target(target_hostname: str, request: Request):
    """
    Calls a target service specified by its hostname and returns its response.
    """
    target_url = f"http://{target_hostname}"

    try:
        # The request is automatically routed through the sidecar proxy.
        async with httpx.AsyncClient() as client:
            response = await client.get(
                target_url, headers=get_trace_headers(request), timeout=5
            )
            response.raise_for_status()  # Raise an exception for 4xx/5xx

        target_message = response.json()["message"]
        return {"message": f"{APP_NAME} <- {target_message}"}

    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,  # Bad Gateway
            detail={
                "message": f"Error response received from {target_hostname}.",
                "target_status_code": exc.response.status_code,
                "target_response": exc.response.text,
            },
        )

    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=503,  # Service Unavailable
            detail=f"Failed to call {target_hostname}. Reason: {exc}",
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected internal error occurred. Reason: {exc}",
        )


@app.get("/call/{proxy_hostname}/{target_hostname}")
async def call_proxy(proxy_hostname: str, target_hostname: str, request: Request):
    """
    Calls a target service specified by its hostname and returns its response.
    """
    proxy_url = f"http://{proxy_hostname}/call/{target_hostname}"

    try:
        # The request is automatically routed through the sidecar proxy.
        async with httpx.AsyncClient() as client:
            response = await client.get(
                proxy_url, headers=get_trace_headers(request), timeout=5
            )
            response.raise_for_status()  # Raise an exception for 4xx/5xx

        proxy_message = response.json()["message"]
        return {"message": f"{APP_NAME} <- {proxy_message}"}

    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,  # Bad Gateway
            detail={
                "message": f"Error response received from {proxy_hostname}.",
                "target_status_code": exc.response.status_code,
                "target_response": exc.response.text,
            },
        )

    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=503,  # Service Unavailable
            detail=f"Failed to call {proxy_hostname}. Reason: {exc}",
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"An unexpected internal error occurred. Reason: {exc}",
        )


@app.get("/resolve-ip/{destination_hostname}")
async def resolve_ip(destination_hostname: str):
    """
    Attempts to resolve the given hostname and returns the result.
    """
    try:
        # Try to resolve the hostname to an IP address.
        ip_address = socket.gethostbyname(destination_hostname)

        return {
            "status": "Success",
            "hostname": destination_hostname,
            "resolved_ip": ip_address,
        }
    except socket.gaierror as e:
        return {
            "status": "Failed",
            "hostname": destination_hostname,
            "error": "Name resolution failed (socket.gaierror)",
            "detail": str(e),
        }
    except Exception as e:
        return {
            "status": "Error",
            "hostname": destination_hostname,
            "error": "An unexpected error occurred",
            "detail": str(e),
        }


TRACE_HEADERS_TO_PROPAGATE = {
    "x-cloud-trace-context",
    "traceparent",
    "tracestate",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "x-request-id",
}


def get_trace_headers(request: Request) -> dict[str, str]:
    return {
        header: value
        for header, value in request.headers.items()
        if header.lower() in TRACE_HEADERS_TO_PROPAGATE
    }


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)
