FROM registry.access.redhat.com/ubi9/python-311:latest

WORKDIR /app
COPY . /app

RUN pip install --upgrade elasticsearch Flask langchain langchain-community langchain-elasticsearch langchain-google-genai openai requests tensorflow tensorflow-hub tensorflow-text

ENV FLASK_APP app.py

CMD ["flask", "run", "--host=0.0.0.0", "--port=8080"]