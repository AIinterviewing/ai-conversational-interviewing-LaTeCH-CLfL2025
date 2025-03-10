import dotenv

# from langchain.chat_models import ChatOpenAI
from langchain_community.chat_models import ChatOpenAI

from langchain.prompts import ChatPromptTemplate
from langchain.schema import StrOutputParser
from langchain.schema.runnable import Runnable
from langchain.schema.runnable.config import RunnableConfig
from langchain_core.runnables.history import RunnableWithMessageHistory
from langchain.memory import ChatMessageHistory
from langchain_core.prompts import MessagesPlaceholder

import chainlit as cl

from pathlib import Path
from openai import OpenAI


dotenv.load_dotenv()


with open('prompt.md') as f:
    prompt_txt = f.read()


async def generate_audio(text):
    client = OpenAI()
    response = client.audio.speech.create(
        model="tts-1",
        voice="alloy",
        input=text
    )
    return response.content


@cl.on_chat_start
async def on_chat_start():
    model = ChatOpenAI(model='gpt-4-turbo-preview', streaming=False)

    prompt = ChatPromptTemplate.from_messages(
        [
            ("system", prompt_txt),
            MessagesPlaceholder(variable_name="chat_history"),
            ("human", "{input}")
        ]
    )

    runnable = prompt | model | StrOutputParser()

    demo_ephemeral_chat_history_for_chain = ChatMessageHistory()

    chain_with_message_history = RunnableWithMessageHistory(
        runnable,
        lambda session_id: demo_ephemeral_chat_history_for_chain,
        input_messages_key="input",
        history_messages_key="chat_history",
    )

    cl.user_session.set("runnable", chain_with_message_history)

    welcome_message = "Welcome to our in-depth interview about democracy. Thank you for participating in our interview. Are you ready to start?"
    welcome_message_audio = await generate_audio(welcome_message)
    elements = [cl.Audio(
        name='', 
        content=welcome_message_audio,
        display="inline")]
    await cl.Message(
        content=welcome_message,
        elements=elements,
    ).send()


@cl.on_message
async def on_message(message: cl.Message):

    runnable = cl.user_session.get("runnable")

    full_response_text = ""
    async for chunk in runnable.astream(
        {"input": message.content},
        config=RunnableConfig(
            callbacks=[cl.LangchainCallbackHandler()],
            configurable={"session_id": "unused"}
            )):
            full_response_text += chunk
    
    response_audio = await generate_audio(full_response_text)
    elements = [cl.Audio(
        name='', 
        content=response_audio,
        display="inline")]

    await cl.Message(
        content=full_response_text,
        elements=elements,
    ).send()
