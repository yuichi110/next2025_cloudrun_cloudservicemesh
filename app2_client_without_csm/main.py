import os
import socket

from fastapi import FastAPI, HTTPException, Request
import httpx
import uvicorn

import google.oauth2.id_token
import google.auth.transport.requests

PORT = int(os.environ.get("PORT", 8080))
APP_NAME = os.environ.get("K_SERVICE", "CLIENT")

app = FastAPI()


@app.get("/")
async def hello():
    """
    Returns a simple greeting message.
    """
    return {"message": APP_NAME}


@app.get("/call-without-authheader/{target_hostname}")
async def call_target(target_hostname: str):
    """
    Calls a target service specified by its hostname and returns its response.
    """
    target_url = f"https://{target_hostname}"

    try:
        # The request is automatically routed through the sidecar proxy.
        async with httpx.AsyncClient() as client:
            response = await client.get(
                target_url, timeout=5
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


@app.get("/call-with-authheader/{target_hostname}")
async def call_target_authheader(target_hostname: str):
    """
    Calls a target service specified by its hostname and returns its response.
    """
    target_url = f"https://{target_hostname}"

    auth_req = google.auth.transport.requests.Request()
    id_token = google.oauth2.id_token.fetch_id_token(auth_req, target_url)
    headers = {"Authorization": f"Bearer {id_token}"}

    try:
        # The request is automatically routed through the sidecar proxy.
        async with httpx.AsyncClient() as client:
            response = await client.get(
                target_url, headers=headers, timeout=5
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


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)
