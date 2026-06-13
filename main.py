import uuid
import re
import asyncio
import os
from typing import Dict
from io import BytesIO

import httpx
from pathlib import Path
from fastapi import Request
from fastapi.responses import FileResponse, StreamingResponse
from fastapi import FastAPI, File, UploadFile, WebSocket, WebSocketDisconnect, BackgroundTasks, Header
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pypdf import PdfReader

app = FastAPI()

# Middleware de Content Security Policy (CSP)
@app.middleware("http")
async def add_csp_header(request: Request, call_next):
    response = await call_next(request)
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
        "font-src https://fonts.gstatic.com 'self'; "
        "img-src 'self' data:; "
        "media-src 'self' blob:; "
        "connect-src 'self' ws: wss: https://*.googleapis.com;"
    )
    return response

# Permite acesso ao diretório static
app.mount("/static", StaticFiles(directory="static"), name="static")

# Permite CORS para desenvolvimento local
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Armazenamento em memória dos blocos de cada sessão
sessions: Dict[str, list] = {
    "mock_capital": [
        '<h2 class="reading-section-title">Seção 1: Mercadoria e Dinheiro</h2>',
        '<div class="reading-block definition"><p><strong>Mercadoria:</strong> É o objeto externo, uma coisa que, por suas propriedades, satisfaz necessidades humanas.</p></div>',
        '<div class="reading-block"><p>A utilidade de uma coisa faz dela um <strong>valor de uso</strong>. Mas esta utilidade não flutua no ar. Condicionada pelas propriedades do corpo da mercadoria, ela não existe sem ele.</p></div>',
        '<div class="reading-block"><p><strong>O Fetiche da Mercadoria:</strong> Um fenômeno onde as relações sociais entre pessoas são mascaradas por relações entre <strong>coisas</strong> e <strong>valores de troca</strong>.</p></div>',
        '<div class="reading-block bordered"><p><strong>1. Valor de Uso:</strong> Refere-se à utilidade de um objeto. O corpo da própria mercadoria, como o ferro, o trigo, o diamante, etc.</p></div>',
        '<div class="reading-block bordered"><p><strong>2. Valor de Troca:</strong> A proporção em que valores de uso de uma espécie se trocam por outros, relação que muda constantemente.</p></div>'
    ],
    "mock_acessibilidade": [
        '<h2 class="reading-section-title">Acessibilidade Digital</h2>',
        '<div class="reading-block definition"><p><strong>Acessibilidade:</strong> É a garantia de que qualquer pessoa, independentemente de suas capacidades físicas ou cognitivas, consiga perceber, compreender, navegar e interagir com produtos digitais.</p></div>',
        '<div class="reading-block"><p>Desenvolver com acessibilidade significa remover barreiras na web. Isso beneficia não apenas pessoas com deficiências permanentes, mas também aquelas com limitações temporárias ou situacionais.</p></div>',
        '<div class="reading-block bordered"><p><strong>Regra de Ouro:</strong> Sempre forneça textos alternativos para imagens, garanta contraste de cores adequado e permita navegação completa via teclado.</p></div>'
    ],
    "mock_design": [
        '<h2 class="reading-section-title">O Design das Coisas</h2>',
        '<div class="reading-block definition"><p><strong>Affordance:</strong> É a relação entre as propriedades de um objeto físico e as capacidades do agente que determinam como o objeto pode ser usado.</p></div>',
        '<div class="reading-block"><p>Quando as coisas simples precisam de fotos, instruções ou avisos, o design falhou. Um bom design deve ser intuitivo e comunicar sua função naturalmente.</p></div>',
        '<div class="reading-block bordered"><p><strong>Feedback:</strong> O princípio de enviar de volta informações sobre qual ação foi realizada e qual resultado foi alcançado. É crucial para o controle e aprendizado.</p></div>'
    ]
}

# Carrega arquivo .env local se existir (para desenvolvimento local)
if os.path.exists(".env"):
    with open(".env", "r") as f:
        for line in f:
            if "=" in line:
                key_env, val_env = line.strip().split("=", 1)
                os.environ[key_env] = val_env

GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"

async def extract_text(file_bytes: bytes) -> str:
    """Extrai texto brutas de um arquivo PDF utilizando PyPDF2."""
    reader = PdfReader(BytesIO(file_bytes))
    text_pages = []
    for page in reader.pages:
        text_pages.append(page.extract_text() or "")
    return "\n".join(text_pages)

async def organize_text_via_groq(raw_text: str, api_key: str) -> str:
    """Envia o texto extraído para o Groq a fim de otimizá-lo para leitura em voz alta."""
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "llama-3.3-70b-versatile",
        "messages": [
            {
                "role": "system",
                "content": (
                    "Você é um assistente editorial inteligente de leitura focada. Seu trabalho é pegar o texto bruto "
                    "extraído de um PDF e reorganizá-lo completamente em blocos de informação estruturados, "
                    "focando em extrair as ideias mais importantes, conceitos-chave, resumos e destaques de forma concisa, dinâmica e visualmente rica.\n"
                    "Siga estas diretrizes de formatação e conteúdo estritamente para criar um design estimulante:\n"
                    "1. ESTRUTURA E TÍTULOS: Sintetize o conteúdo original. Para títulos principais de seções, use "
                    "<h2 class=\"reading-section-title\">Título da Seção</h2>.\n"
                    "2. VARIEDADE DE CARDS (Escolha o tipo de card ideal para cada trecho):\n"
                    "   - Card Padrão: <div class=\"reading-block\"><p>...</p></div> (para parágrafos comuns de conteúdo).\n"
                    "   - Card de Definição (Fundo Lavanda): <div class=\"reading-block definition\"><p><span class=\"badge\">Conceito</span><strong>Termo:</strong> Explicação...</p></div> (para conceitos teóricos centrais e glossários).\n"
                    "   - Card de Alerta/Atenção (Fundo Amarelo Suave, Borda Laranja): <div class=\"reading-block warning\"><p><strong>Atenção:</strong> Regras críticas, exceções importantes ou proibições.</p></div>.\n"
                    "   - Card de Citação (Fundo Cinza, Itálico): <div class=\"reading-block quote\"><p><em>\"Citação direta do autor ou artigo de lei importante\"</em></p></div>.\n"
                    "   - Card Bordado (Borda Azul à Esquerda): <div class=\"reading-block bordered\"><p>... e listas ordenadas/passo a passo.</p></div>.\n"
                    "3. RECURSOS VISUAIS INTERNOS (Para destacar partes importantes e evitar monotonia):\n"
                    "   - Negrito Azul: Use <strong> para termos fundamentais e palavras-chave principais.\n"
                    "   - Marcador Amarelo (Estilo Marca-texto): Use a tag <mark> para destacar trechos de extrema importância que merecem atenção total do leitor (como números de leis, estatísticas críticas ou conclusões definitivas).\n"
                    "   - Badges/Etiquetas: Use <span class=\"badge\">Etiqueta</span> (por exemplo: CONCEITO, LEI, HISTÓRICO, IMPORTANTE) no início do texto do card para categorizar a informação.\n"
                    "   - Subtítulos nos Cards: Use a tag <h3> dentro dos cards para subdividir ideias ou colocar subseções.\n"
                    "   - Listas: Use <ul> e <li> para enumerar pontos de forma visual.\n"
                    "4. FLUIDEZ DE ÁUDIO: Escreva em Português do Brasil claro. Certifique-se de que o texto soe natural e agradável quando narrado em voz alta.\n"
                    "5. RETORNO LIMPO: Retorne estritamente o código HTML bruto gerado, sem blocos de código markdown (como ```html) ou textos explicativos."
                )
            },
            {
                "role": "user",
                "content": raw_text
            }
        ],
        "temperature": 0.3
    }
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(GROQ_URL, json=payload, headers=headers)
            if response.status_code == 200:
                data = response.json()
                return data["choices"][0]["message"]["content"]
            else:
                print(f"Erro ao chamar o Groq ({response.status_code}): {response.text}")
    except Exception as e:
        print(f"Falha na integração com Groq: {e}")
    return raw_text

def clean_html_for_tts(html_text: str) -> str:
    """Substitui tags de bloco por quebras de linha e limpa as demais tags HTML para evitar leitura incorreta."""
    text = re.sub(r'</?(div|p|h1|h2|h3|br)[^>]*>', '\n', html_text)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'\n+', '\n', text)
    return text.strip()

def split_html_into_blocks(html_content: str):
    """Divide o HTML retornado pelo Groq em blocos individuais (cards ou títulos de seção)."""
    # Encontra blocos de leitura e títulos com base nas classes
    pattern = r'(<div class="reading-block[^>]*>.*?</div>|<h2 class="reading-section-title">.*?</h2>)'
    blocks = re.findall(pattern, html_content, re.DOTALL)
    
    # Se falhar, divide por parágrafos
    if not blocks:
        blocks = [f'<div class="reading-block"><p>{p.strip()}</p></div>' for p in html_content.split('\n\n') if p.strip()]
    if not blocks:
        blocks = [html_content]
    return [b.strip() for b in blocks if b.strip()]

@app.get("/", response_class=FileResponse)
async def serve_index():
    return FileResponse(Path(__file__).parent / "index.html")

raw_sessions: Dict[str, list] = {}
structured_sessions: Dict[str, Dict[int, list]] = {}

async def pre_structure_session(session_id: str, chunks: list, client_key: str):
    """Estrutura os chunks em segundo plano, respeitando limites de RPM/TPM."""
    semaphore = asyncio.Semaphore(2)
    
    async def worker(chunk_content: str, idx: int):
        if session_id not in raw_sessions:
            return
        if session_id in structured_sessions and idx in structured_sessions[session_id]:
            return
        try:
            await asyncio.sleep(1.0 * idx) # Delay progressivo
            print(f"[Background] Estruturando chunk {idx+1}/{len(chunks)}...")
            organized_text = await organize_text_via_groq(chunk_content, client_key)
            chunk_blocks = split_html_into_blocks(organized_text)
            if session_id not in structured_sessions:
                structured_sessions[session_id] = {}
            structured_sessions[session_id][idx] = chunk_blocks
            print(f"[Background] Chunk {idx+1}/{len(chunks)} concluído")
        except Exception as e:
            print(f"[Background] Erro no chunk {idx}: {e}")

    tasks = [worker(c, i) for i, c in enumerate(chunks)]
    await asyncio.gather(*tasks)

@app.post("/upload")
async def upload_pdf(background_tasks: BackgroundTasks, file: UploadFile = File(...), x_groq_api_key: str = Header(None)):
    session_id = str(uuid.uuid4())
    file_bytes = await file.read()
    print(f"[Upload] Recebido arquivo: {file.filename} ({len(file_bytes)} bytes)")
    
    reader = PdfReader(BytesIO(file_bytes))
    chunks = []
    current_chunk = []
    current_len = 0
    
    # Extrai o texto organizando-o página por página
    for i, page in enumerate(reader.pages):
        page_text = page.extract_text() or ""
        page_text = page_text.strip()
        if not page_text:
            continue
        
        # Agrupa páginas até atingir cerca de 8000 caracteres por chunk
        if current_len + len(page_text) > 8000 and current_chunk:
            chunks.append("\n\n".join(current_chunk))
            current_chunk = [page_text]
            current_len = len(page_text)
        else:
            current_chunk.append(page_text)
            current_len += len(page_text) + 2
            
    if current_chunk:
        chunks.append("\n\n".join(current_chunk))

    # Valida se conseguimos extrair texto
    if not chunks:
        print(f"[Upload] O texto extraído é nulo ou curto. Retornando aviso de PDF escaneado.")
        blocks = [
            "<div class=\"reading-block definition\">"
            "<h2>Aviso de Leitura</h2>"
            "<p><strong>Não conseguimos extrair texto legível deste PDF.</strong></p>"
            "<p>Parece que este arquivo contém apenas imagens digitalizadas/escaneadas ou não possui uma camada de texto acessível. "
            "Por favor, envie um PDF que contenha texto digital selecionável para que o leitor possa narrá-lo.</p>"
            "</div>"
        ]
        sessions[session_id] = blocks
        return JSONResponse(content={"session_id": session_id, "total_chunks": 1, "blocks": blocks})

    # Armazena chunks originais e inicia armazenamento estruturado
    raw_sessions[session_id] = chunks
    structured_sessions[session_id] = {}
    print(f"[Upload] PDF dividido em {len(chunks)} chunks de páginas. Iniciando estruturação em background...")
    
    client_key = x_groq_api_key or GROQ_API_KEY
    background_tasks.add_task(pre_structure_session, session_id, chunks, client_key)
    
    # Retorna imediatamente com o session_id e o total de chunks
    return JSONResponse(content={
        "session_id": session_id,
        "total_chunks": len(chunks),
        "title": file.filename.replaceAll('.pdf', '') if hasattr(file.filename, 'replaceAll') else file.filename.replace('.pdf', '')
    })

@app.get("/session/{session_id}/chunk/{chunk_index}")
async def get_session_chunk(session_id: str, chunk_index: int, x_groq_api_key: str = Header(None)):
    # Caso seja um mock, retorna todo o mock como único chunk
    if session_id.startswith("mock_"):
        if session_id not in sessions:
            return JSONResponse(status_code=404, content={"detail": "Mock de sessão não encontrado."})
        return {"blocks": sessions[session_id]}

    if session_id not in raw_sessions:
        return JSONResponse(status_code=404, content={"detail": "Sessão não encontrada."})
    
    chunks = raw_sessions[session_id]
    if chunk_index < 0 or chunk_index >= len(chunks):
        return JSONResponse(status_code=404, content={"detail": "Índice de chunk inválido."})
    
    # Se já estruturado, retorna imediatamente
    if session_id in structured_sessions and chunk_index in structured_sessions[session_id]:
        return {"blocks": structured_sessions[session_id][chunk_index]}
    
    # Se ainda não estiver estruturado, processa sob demanda (síncrono rápido)
    print(f"[Upload] Processando chunk {chunk_index} sob demanda (bloqueante rápido)...")
    chunk_content = chunks[chunk_index]
    client_key = x_groq_api_key or GROQ_API_KEY
    organized_text = await organize_text_via_groq(chunk_content, client_key)
    chunk_blocks = split_html_into_blocks(organized_text)
    
    if session_id not in structured_sessions:
        structured_sessions[session_id] = {}
    structured_sessions[session_id][chunk_index] = chunk_blocks
    
    return {"blocks": chunk_blocks}

@app.get("/mock-session/{mock_id}")
async def get_mock_session(mock_id: str):
    full_mock_id = f"mock_{mock_id}"
    if full_mock_id not in sessions:
        return JSONResponse(status_code=404, content={"detail": "Mock de sessão não encontrado."})
    
    title = "O Capital - Livro I"
    if mock_id == "acessibilidade":
        title = "Manual de Acessibilidade"
    elif mock_id == "design":
        title = "Design do Dia a Dia"
        
    return {
        "session_id": full_mock_id,
        "blocks": sessions[full_mock_id],
        "title": title
    }

import edge_tts

@app.get("/stream-audio/{session_id}/{block_index}")
async def stream_audio(session_id: str, block_index: int, voice: str = "pt-BR-FranciscaNeural"):
    if session_id not in sessions:
        return JSONResponse(status_code=404, content={"detail": "Sessão não encontrada."})
    
    blocks = sessions[session_id]
    if block_index < 0 or block_index >= len(blocks):
        return JSONResponse(status_code=404, content={"detail": "Bloco não encontrado."})
    
    html_text = blocks[block_index]
    text_to_speak = clean_html_for_tts(html_text)
    
    # Remove concept badges from TTS readout
    text_to_speak = re.sub(r'^(Conceito|Importante|Teoria|Atenção|Aviso|Lei)\s*:\s*', '', text_to_speak, flags=re.IGNORECASE)
    text_to_speak = re.sub(r'^(Conceito|Importante|Teoria|Atenção|Aviso|Lei)\s*\-\s*', '', text_to_speak, flags=re.IGNORECASE)
    
    try:
        communicate = edge_tts.Communicate(text_to_speak, voice)
        
        async def audio_generator():
            async for chunk in communicate.stream():
                if chunk["type"] == "audio":
                    yield chunk["data"]
                    
        return StreamingResponse(audio_generator(), media_type="audio/mpeg")
    except Exception as e:
        print(f"Erro no Edge TTS: {e}")
        return JSONResponse(status_code=500, content={"detail": f"Erro na síntese: {str(e)}"})

@app.get("/download-apk")
async def download_apk():
    apk_path = Path(__file__).parent / "flutter_client" / "build" / "app" / "outputs" / "flutter-apk" / "app-debug.apk"
    if apk_path.exists():
        return FileResponse(
            path=apk_path,
            filename="lumina-reader.apk",
            media_type="application/vnd.android.package-archive"
        )
    return JSONResponse(status_code=404, content={"message": "Arquivo APK não encontrado. Compile o app primeiro."})
