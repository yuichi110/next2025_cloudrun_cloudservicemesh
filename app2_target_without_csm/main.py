import os
import uvicorn
from fastapi import FastAPI

PORT = int(os.environ.get("PORT", 8082))
APP_NAME = os.environ.get("K_SERVICE", "TARGET")

app = FastAPI()


@app.get("/")
async def respond_hello():
    """
    Returns a simple greeting message.
    """
    return {"message": APP_NAME}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=PORT)
