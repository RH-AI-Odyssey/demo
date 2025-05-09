from elasticsearch                    import Elasticsearch
from flask                            import Flask, request
from json                             import dumps
from langchain.chains                 import RetrievalQA
from langchain_community.embeddings   import TensorflowHubEmbeddings
from langchain_community.vectorstores import ElasticsearchStore
from langchain_community.llms         import VLLMOpenAI
from langchain_google_genai           import ChatGoogleGenerativeAI
from os                               import getenv
from requests                         import get

ELASTICSEARCH_HOST                 = getenv('ELASTICSEARCH_HOST')
ELASTICSEARCH_USERNAME             = getenv('ELASTICSEARCH_USERNAME')
ELASTICSEARCH_PASSWORD             = getenv('ELASTICSEARCH_PASSWORD')
ELASTICSEARCH_DOCUMENT_INDEX       = getenv('ELASTICSEARCH_DOCUMENT_INDEX')
ELASTICSEARCH_TELEGRAM_INDEX       = getenv('ELASTICSEARCH_TELEGRAM_INDEX')
TENSORFLOW_HUB_EMBEDDING_MODEL_URL = getenv('TENSORFLOW_HUB_EMBEDDING_MODEL_URL')
GOOGLE_API_KEY                     = getenv('GOOGLE_API_KEY', default = 'GOOGLE_API_KEY')
GOOGLE_MODEL                       = getenv('GOOGLE_MODEL')
GOOGLE_MODEL_MAX_TOKENS            = getenv('GOOGLE_MODEL_MAX_TOKENS')
TELEGRAM_TOKEN                     = getenv('TELEGRAM_TOKEN', default = 'TELEGRAM_TOKEN')
TELEGRAM_API                       = f'https://api.telegram.org/bot{ TELEGRAM_TOKEN }'
MODEL_INFERENCE_SERVICE            = getenv('MODEL_INFERENCE_SERVICE')
MODEL_INFERENCE_NAME               = getenv('MODEL_INFERENCE_NAME')

app = Flask(__name__)

elasticsearch_client = Elasticsearch(
    hosts        = ELASTICSEARCH_HOST,
    basic_auth   = (ELASTICSEARCH_USERNAME, ELASTICSEARCH_PASSWORD),
    verify_certs = False
)

embedding = TensorflowHubEmbeddings(
    model_url = TENSORFLOW_HUB_EMBEDDING_MODEL_URL
)

elasticsearch_store = ElasticsearchStore(
    es_connection = elasticsearch_client,
    index_name    = ELASTICSEARCH_DOCUMENT_INDEX,
    embedding     = embedding
)

if GOOGLE_API_KEY and GOOGLE_API_KEY != "GOOGLE_API_KEY":
    gemini_llm = ChatGoogleGenerativeAI(
        google_api_key = GOOGLE_API_KEY,
        model          = GOOGLE_MODEL,
        max_tokens     = 200
    )

    gemini_retrieval_qa = RetrievalQA.from_llm(
        llm       = gemini_llm,
        retriever = elasticsearch_store.as_retriever(),
    )

mistral_llm = VLLMOpenAI(
    openai_api_key="EMPTY",
    openai_api_base= f"{MODEL_INFERENCE_SERVICE}/v1",
    model_name= f"{MODEL_INFERENCE_NAME}",
)

mistral_retrieval_qa = RetrievalQA.from_llm(
    llm       = mistral_llm,
    retriever = elasticsearch_store.as_retriever(),
)

@app.route('/', methods = ['POST'])
def handle_message() -> dict:

    if not TELEGRAM_TOKEN or TELEGRAM_TOKEN == "TELEGRAM_TOKEN":

        print("Please, configure TELEGRAM_TOKEN environment variable.")
        return {}

    # create response

    message = {
        'request'  : request.json,
        'response' : {}
    }

    # handle text request

    request_text = message['request']['text']

    if request_text is not None:

        # /start

        if request_text.startswith('/start'):

            first_name    = message['request']['from']['first_name']
            response_text = f'Hello { first_name }! How can I help you today?'

        # /gemini

        elif request_text.startswith('/gemini'):

            try:

                response_text = gemini_llm.invoke(request_text.replace('/gemini', '').strip()).content

            except Exception as exception:

                response_text = f'Error when calling LLM: { exception.message }'

        # /gemini-rag

        elif request_text.startswith('/gemini-rag'):

            try:

                params = {
                    'query' : request_text.replace('/gemini-rag', '').strip()
                }

                response_text = gemini_retrieval_qa.invoke(params)['result']

            except Exception as exception:

                response_text = f'Error when calling LLM: { exception.message }'

        # /mistral

        elif request_text.startswith('/mistral'):

            try:

                response_text = mistral_llm.invoke(request_text.replace('/mistral', '').strip())

            except Exception as exception:

                response_text = f'Error when calling LLM: { exception.message }'

        # /mistral-rag

        else:

            try:

                params = {
                    'query' : request_text
                }

                response_text = mistral_retrieval_qa.invoke(params)['result']

            except Exception as exception:

                response_text = 'Error when calling LLM, please try again.'
                print(f'Error: { exception.message }')

        # send text response

        params = {
            'chat_id' : message['request']['chat']['id'],
            'text'    : response_text
        }

        api = f'{ TELEGRAM_API }/sendMessage'
        get(url = api, params = params)

        # update response

        message['response']['text'] = response_text

    # handle image request
    # TODO

    # save
    # TODO

    # return

    print(dumps(message, indent = 4))
    return message