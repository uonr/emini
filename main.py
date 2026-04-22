import os
import asyncio

from gemini_webapi import GeminiClient
from gemini_webapi.constants import Model

async def _main():
    _1PS_ID = os.getenv("SECURE_1PS_ID")
    _1PS_IDTS = os.getenv("SECURE_1PS_IDTS")
    client = GeminiClient(_1PS_ID, _1PS_IDTS, proxy=None)
    await client.init(timeout=30, auto_close=False, close_delay=300, auto_refresh=True)
    chat = client.start_chat(model=Model.PLUS_FLASH)
    response = await chat.send_message("Hello World!")
    print(response.text)
    await client.delete_chat(chat.cid)


def main():
    asyncio.run(_main())


if __name__ == "__main__":
    main()
