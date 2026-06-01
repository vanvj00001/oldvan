#!/usr/bin/env python3
"""
NVIDIA Proxy for Codex (NVIDIA 原生流式透传版)
策略：
1. 接收 Codex 请求
2. 以流式模式请求 NVIDIA (stream=True)
3. 将 NVIDIA 返回的每一行 SSE 数据原封不动地转发给 Codex
优点：100% 兼容 NVIDIA 的 SSE 格式，Codex 应该能识别
"""

import os
import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import StreamingResponse
import httpx

app = FastAPI()

NVIDIA_API_KEY = os.getenv("NVIDIA_API_KEY", "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")
NVIDIA_BASE_URL = "https://integrate.api.nvidia.com/v1"

MODEL_MAP = {
    "nvidia-proxy/llama-3.1-405b": "meta/llama-3.1-405b-instruct",
    "nvidia-proxy/llama-3.1-70b": "meta/llama-3.1-70b-instruct",
    # 新增：支持直接传入 NVIDIA 官方模型 ID
    "meta/llama-3.1-405b-instruct": "meta/llama-3.1-405b-instruct",
    "meta/llama-3.1-70b-instruct": "meta/llama-3.1-70b-instruct",
    "default": "meta/llama-3.1-405b-instruct"
}

def get_real_model(model_name: str) -> str:
    # 如果模型名在映射表中，直接返回对应的值
    if model_name in MODEL_MAP:
        return MODEL_MAP[model_name]
    # 如果不在，且看起来是合法的 NVIDIA 模型名 (包含 / )，直接透传
    if "/" in model_name:
        return model_name
    # 否则使用默认值
    return MODEL_MAP.get("default")

def clean_message(msg):
    if isinstance(msg, str): return msg
    if isinstance(msg, dict):
        if msg.get("type") == "input_text": return msg.get("text", "")
        if msg.get("type") == "message":
            content = msg.get("content", [])
            if isinstance(content, list):
                texts = []
                for item in content:
                    if isinstance(item, dict) and item.get("type") == "input_text": texts.append(item.get("text", ""))
                    elif isinstance(item, str): texts.append(item)
                return "\n".join(texts) if texts else ""
            elif isinstance(content, str): return content
        if "content" in msg and isinstance(msg["content"], str): return msg["content"]
    return str(msg)

def convert_to_chat_messages(raw_input) -> list:
    messages = []
    if isinstance(raw_input, str): messages.append({"role": "user", "content": raw_input})
    elif isinstance(raw_input, list):
        for item in raw_input:
            clean_text = clean_message(item)
            if clean_text:
                role = "user"
                if isinstance(item, dict):
                    role = item.get("role", "user")
                    if role == "developer": role = "user"
                messages.append({"role": role, "content": clean_text})
    return messages

@app.post("/v1/responses")
async def proxy_responses(request: Request):
    try:
        body = await request.json()
        model_name = body.get("model", "default")
        real_model = get_real_model(model_name)
        
        print(f"📥 Request: {model_name}")

        # 1. 转换格式
        raw_input = body.get("input", [])
        messages = convert_to_chat_messages(raw_input)
        if not messages: messages = [{"role": "user", "content": "Hello"}]

        # 2. 构建给 NVIDIA 的请求 (强制开启流式)
        nvidia_body = {
            "model": real_model,
            "messages": messages,
            "stream": True,  # 强制流式
            "max_tokens": body.get("max_output_tokens", 4096)
        }

        # 3. 创建流式生成器
        async def generate():
            try:
                print(f"🚀 Connecting to NVIDIA (Stream)...")
                async with httpx.AsyncClient() as client:
                    async with client.stream(
                        "POST",
                        f"{NVIDIA_BASE_URL}/chat/completions",
                        json=nvidia_body,
                        headers={"Authorization": f"Bearer {NVIDIA_API_KEY}", "Content-Type": "application/json"},
                        timeout=120.0
                    ) as response:
                        if response.status_code != 200:
                            print(f"❌ NVIDIA Error: {response.status_code}")
                            yield f'data: {{"error": {{"message": "NVIDIA API Error {response.status_code}"}}}}\n\n'
                            return

                        async for line in response.aiter_lines():
                            # 原样透传 NVIDIA 的每一行 SSE 数据
                            if line.strip():
                                # NVIDIA 返回的是 "data: {...}"
                                # 我们直接 yield 这一行 + 两个换行符 (SSE 标准)
                                yield f"{line}\n\n"
                            else:
                                yield "\n\n"
                
                # 确保发送 [DONE]
                yield "data: [DONE]\n\n"
                print("✅ Stream finished.")

            except Exception as e:
                print(f"💥 Stream Error: {e}")
                yield f'data: {{"error": {{"message": "{str(e)}"}}}}\n\n'

        return StreamingResponse(generate(), media_type="text/event-stream")

    except Exception as e:
        print(f"Internal Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    print("🚀 Starting NVIDIA Proxy (Native Stream Passthrough) ...")
    uvicorn.run(app, host="0.0.0.0", port=8080)