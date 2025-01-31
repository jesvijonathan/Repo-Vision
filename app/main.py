import os
from langchain_community.document_loaders import TextLoader
from langchain.text_splitter import CharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from openai import OpenAI
from langchain.schema import Document
import time
import re
from config import *

# Configuration
STOPS = ['<´¢£endÔûüofÔûüsentence´¢£>']
COUNTERLIMITS = 10  # an even number
modelname = 'DeepSeek-R1-Distill-Qwen-1.5B'
NCTX = 131072
CHUNK_SIZE = 2000  # Max chunk size in tokens

# Load documents from all files in a directory
def load_documents_from_directory(target_project_path):
    documents = []
    metadata = []
    
    # Loop through each file in the directory
    for filename in os.listdir(target_project_path):
        print(f"Loading file: {filename}")
        file_path = os.path.join(target_project_path, filename)
        
        if os.path.isfile(file_path):  # Ensure it's a file
            loader = TextLoader(file_path)
            raw_documents = loader.load()
            documents.extend(raw_documents)
            
            # Add metadata for each document
            for doc in raw_documents:
                doc.metadata = {'file_name': filename, 'file_path': file_path, 'file_size': os.path.getsize(file_path), 'file_last_modified': os.path.getmtime(file_path), 'file_created': os.path.getctime(file_path), 'file_extension': os.path.splitext(filename)[1], 'file_directory': os.path.dirname(file_path), 'file_base_name': os.path.basename(file_path), 'file_stem': os.path.splitext(filename)[0], 'file_encoding': loader.encoding if hasattr(loader, 'encoding') else None}
                metadata.append(doc.metadata)
    
    return documents, metadata

# Clean and preprocess document text
def clean_text(text):
    # Remove unnecessary whitespace, special characters, and extra spaces
    text = re.sub(r'\s+', ' ', text)  # Replace multiple spaces with a single space
    text = re.sub(r'[^\x00-\x7F]+', ' ', text)  # Remove non-ASCII characters
    return text.strip()

# Tokenize the context and question to fit within the model's token limit
def tokenize_and_filter(context, question, max_tokens=32000):
    context_tokens = context.split()  # Basic tokenization (split by whitespace)
    question_tokens = question.split()
    
    # Calculate remaining token space for context
    available_tokens = max_tokens - len(question_tokens)
    
    # Filter context to fit within available token space
    filtered_context = " ".join(context_tokens[:available_tokens])
    
    return filtered_context, question_tokens


# vectorstore = FAISS.load_local("path_to_save_vectorstore", embeddings)

documents, metadata = load_documents_from_directory(target_project_path)

# Initialize embeddings model
embeddings = HuggingFaceEmbeddings(model_name="thenlper/gte-large")

# Split documents into chunks based on token size
def chunk_documents(documents, chunk_size=CHUNK_SIZE):
    chunks = []
    metadata = []
    splitter = CharacterTextSplitter(chunk_size=chunk_size, chunk_overlap=50)  # No overlap to simplify
    
    for doc in documents:
        # Split document content into smaller chunks
        doc_chunks = splitter.split_text(doc.page_content)
        for chunk in doc_chunks:
            # Create a Document object with chunk and metadata
            document = Document(page_content=chunk, metadata=doc.metadata)
            chunks.append(document)  # Append Document object
    
    return chunks, metadata



# Vectorize document chunks
document_chunks, document_metadata = chunk_documents(documents)

# Create FAISS vector database from chunks
vectorstore = FAISS.from_documents(document_chunks, embeddings)
# vectorstore.save_local("./my_vectorstore")
# Create retriever using vector store
retriever = vectorstore.as_retriever()

# Set up RAG pipeline with local DeepSeek model
client = OpenAI(base_url="http://localhost:8080/v1", api_key="not-needed", organization=modelname)

history = [{"role": "system", "content": "You are the AI that has an entire repository of documents, code, specification, etc at your disposal. Use it to answer technical questions. Keep it short and concise, give only the most relevant information."}]

def query_deepseek(prompt: str):
    global history
    history.append({"role": "user", "content": prompt})
    
    # Stream response from OpenAI
    completion = client.chat.completions.create(
        model="local-model",
        messages=history,
        temperature=0.7,
        frequency_penalty=0.2,
        max_tokens=100,
        stop=STOPS,
        stream=True
    )
    
    # Handle and display streaming output
    new_message = {"role": "assistant", "content": ""}
    for chunk in completion:
        if chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="", flush=True)
            new_message["content"] += chunk.choices[0].delta.content
    
    history.append(new_message)

def query_rag(question):
    # Retrieve relevant chunks, limit the number of results
    relevant_chunks = retriever.invoke(question, top_k=3)  # Limit to top 5 chunks for faster response
    
    if not relevant_chunks:
        print("No relevant chunks found.")
        return
    else:
        print(f"Found {len(relevant_chunks)} relevant chunks.")
    
    # Extract paths from metadata and load full content if necessary
    context = "\n".join([clean_text(chunk.page_content) for chunk in relevant_chunks])
    doc_paths = [chunk.metadata['file_path'] for chunk in relevant_chunks]
    
    # Retrieve full content from the original files if necessary
    full_contents = []
    for path in doc_paths:
        with open(path, 'r', encoding='utf-8') as file:
            full_contents.append(file.read())
    
    # Tokenize and filter context to fit within token limits
    full_context = " ".join(full_contents)
    filtered_context, question_tokens = tokenize_and_filter(context, question, max_tokens=32000)
    
    final_prompt = f"question: {question_tokens} documents: {filtered_context}"
    
    # Query the DeepSeek model
    query_deepseek(final_prompt)

# Main loop to interact with the user
def main():
    print("RAG-based application with DeepSeek is running! Type 'exit' to quit.")
    
    while True:
        user_input = input("Please enter your question: ")
        
        if user_input.lower() == 'exit':
            print("Exiting the application.")
            break
        
        start_time = time.time()
        query_rag(user_input)
        print(f"\nTime taken for query: {time.time() - start_time:.2f} seconds")

if __name__ == "__main__":
    main()
