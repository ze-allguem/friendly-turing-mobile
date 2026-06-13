// Elementos da Página Inicial (Home)
const homeView = document.getElementById('home-view');
const dropZone = document.getElementById('drop-zone');
const fileInput = document.getElementById('file-input');
const selectBtn = document.getElementById('select-btn');
const themeToggleBtn = document.getElementById('theme-toggle');
const recentItems = document.querySelectorAll('.recent-item');

// Elementos do Leitor (Reader)
const readerView = document.getElementById('reader-view');
const backBtn = document.getElementById('back-btn');
const headerTitle = document.getElementById('header-title');
const textContainer = document.getElementById('text-container');
const textContent = document.getElementById('text-content');

// Elementos de Playback
const audioPlayer = document.getElementById('audio-player');
const playPauseBtn = document.getElementById('play-pause-btn');
const playIconSymbol = document.getElementById('play-icon-symbol');
const prevBtn = document.getElementById('prev-btn');
const nextBtn = document.getElementById('next-btn');

// Elementos do Seletor de Voz
const voiceBtn = document.getElementById('voice-btn');
const voiceDropdownMenu = document.getElementById('voice-dropdown-menu');
const voiceOptions = document.querySelectorAll('.voice-option');

// Elementos do Seletor de Velocidade
const speedBtn = document.getElementById('speed-btn');
const speedDropdownMenu = document.getElementById('speed-dropdown-menu');
const speedOptions = document.querySelectorAll('.speed-option');
const activeSpeedLabel = document.getElementById('active-speed-label');

// Estado da Aplicação
let currentSessionId = null;
let currentBlockIndex = 0;
let currentSpeed = 1.2;
let selectedVoiceId = "pt-BR-FranciscaNeural"; // Francisca como padrão

// ================= NAVEGAÇÃO DE TELAS (SPA) =================

function showHomeView() {
  // Para e limpa o player
  audioPlayer.pause();
  audioPlayer.src = '';
  updatePlayPauseIcon(false);
  
  // Limpa os blocos
  textContent.innerHTML = '';
  currentSessionId = null;
  currentBlockIndex = 0;

  // Transiciona as telas
  readerView.classList.add('hidden');
  homeView.classList.remove('hidden');
}

function showReaderView(title, blocks, sessionId) {
  headerTitle.textContent = title;
  
  // Limpa e renderiza os blocos
  textContent.innerHTML = '';
  blocks.forEach((blockHtml, index) => {
    const wrapper = document.createElement('div');
    wrapper.innerHTML = blockHtml.trim();
    const element = wrapper.firstElementChild;
    if (element) {
      element.setAttribute('data-index', index);
      element.classList.add('clickable-block');
      textContent.appendChild(element);
    }
  });

  homeView.classList.add('hidden');
  readerView.classList.remove('hidden');

  // Inicializa o primeiro bloco destacado mas sem iniciar a leitura (evita consumo de créditos)
  playBlock(sessionId, 0, false);
}

// Ouvinte do Botão de Voltar do Leitor
if (backBtn) {
  backBtn.addEventListener('click', showHomeView);
}

// ================= SELEÇÃO DE ARQUIVO & DRAG & DROP =================

if (selectBtn && fileInput) {
  selectBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    fileInput.click();
  });
}

if (dropZone) {
  dropZone.addEventListener('click', () => {
    fileInput.click();
  });

  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('dragover');
  });

  dropZone.addEventListener('dragleave', () => {
    dropZone.classList.remove('dragover');
  });

  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('dragover');
    const files = e.dataTransfer.files;
    if (files.length) {
      handleFile(files[0]);
    }
  });
}

if (fileInput) {
  fileInput.addEventListener('change', (e) => {
    if (e.target.files.length) {
      handleFile(e.target.files[0]);
    }
  });
}

async function handleFile(file) {
  if (!file || file.type !== 'application/pdf') {
    alert('Por favor, envie apenas arquivos PDF.');
    return;
  }

  // Prepara o formulário
  const form = new FormData();
  form.append('file', file);

  // Exibe estado de carregamento no upload zone
  const uploadPara = dropZone.querySelector('p');
  const originalParaText = uploadPara.textContent;
  uploadPara.textContent = 'Aguarde, a IA está organizando o texto...';
  selectBtn.textContent = 'Processando...';
  selectBtn.disabled = true;

  try {
    const uploadResp = await fetch('/upload', { method: 'POST', body: form });
    if (!uploadResp.ok) {
      throw new Error('Falha no upload do arquivo.');
    }
    
    const { session_id, blocks } = await uploadResp.json();
    
    // Reseta estado do upload zone
    uploadPara.textContent = originalParaText;
    selectBtn.textContent = 'Selecionar Arquivo';
    selectBtn.disabled = false;
    fileInput.value = '';

    if (blocks && blocks.length > 0) {
      const displayTitle = file.name.replace(/\.[^/.]+$/, "");
      showReaderView(displayTitle, blocks, session_id);
    } else {
      alert('Nenhum conteúdo legível encontrado no PDF.');
    }
  } catch (error) {
    console.error(error);
    alert('Erro ao processar o arquivo PDF. Tente novamente.');
    
    // Reseta estado do upload zone
    uploadPara.textContent = originalParaText;
    selectBtn.textContent = 'Selecionar Arquivo';
    selectBtn.disabled = false;
    fileInput.value = '';
  }
}

// ================= CONTROLES DE RECENTES (MOCK DATA) =================

recentItems.forEach(item => {
  item.addEventListener('click', async () => {
    const mockId = item.getAttribute('data-mock');
    if (!mockId) return;

    try {
      const resp = await fetch(`/mock-session/${mockId}`);
      if (!resp.ok) {
        throw new Error('Falha ao carregar sessão mockada.');
      }
      const { session_id, blocks, title } = await resp.json();
      showReaderView(title, blocks, session_id);
    } catch (err) {
      console.error(err);
      alert('Erro ao carregar livro recente.');
    }
  });
});

// ================= CONTROLE DE ÁUDIO & KARAOKE =================

function playBlock(sessionId, index, shouldPlay = true) {
  currentSessionId = sessionId;
  currentBlockIndex = index;
  
  const allBlocks = document.querySelectorAll('.clickable-block');
  
  // Remove destaque anterior de todos os blocos
  allBlocks.forEach(b => b.classList.remove('highlight'));
  
  // Aplica destaque ao bloco atual
  const activeBlock = document.querySelector(`.clickable-block[data-index="${index}"]`);
  if (activeBlock) {
    activeBlock.classList.add('highlight');
    activeBlock.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }

  // Se for apenas para destacar (como no carregamento inicial), não carrega áudio
  if (!shouldPlay) {
    audioPlayer.src = '';
    updatePlayPauseIcon(false);
    return;
  }

  // Define o src de streaming de áudio contendo a voz local do Edge-TTS
  audioPlayer.src = `/stream-audio/${sessionId}/${index}?voice=${selectedVoiceId}`;
  
  // Garante a velocidade de reprodução correta no player
  audioPlayer.defaultPlaybackRate = currentSpeed;
  audioPlayer.playbackRate = currentSpeed;
  
  audioPlayer.play()
    .then(() => {
      updatePlayPauseIcon(true);
    })
    .catch(err => {
      console.log('Autoplay interrompido ou requer interação do usuário:', err);
      updatePlayPauseIcon(false);
    });
}

// Listener para forçar a velocidade correta quando o áudio começar a reproduzir
audioPlayer.addEventListener('play', () => {
  audioPlayer.playbackRate = currentSpeed;
});

// Listener de fim de bloco (não avança automaticamente para evitar consumo excessivo de créditos)
audioPlayer.addEventListener('ended', () => {
  updatePlayPauseIcon(false);
  // Para poupar créditos da Cartesia, removemos o avanço automático de blocos.
  // O usuário deve clicar em outro card ou utilizar os botões do controlador para continuar.
});

// Click nos blocos do leitor para saltar para o trecho correspondente
textContent.addEventListener('click', (e) => {
  const block = e.target.closest('.clickable-block');
  if (block && currentSessionId) {
    const index = parseInt(block.getAttribute('data-index'), 10);
    playBlock(currentSessionId, index);
  }
});

// Controles de Play / Pause
function updatePlayPauseIcon(isPlaying) {
  if (isPlaying) {
    playIconSymbol.textContent = 'pause';
  } else {
    playIconSymbol.textContent = 'play_arrow';
  }
}

if (playPauseBtn) {
  playPauseBtn.addEventListener('click', () => {
    if (audioPlayer.paused) {
      if (!audioPlayer.src && currentSessionId) {
        playBlock(currentSessionId, currentBlockIndex);
      } else {
        audioPlayer.play()
          .then(() => updatePlayPauseIcon(true))
          .catch(e => console.error(e));
      }
    } else {
      audioPlayer.pause();
      updatePlayPauseIcon(false);
    }
  });
}

// Controles de Pular (Próximo / Anterior)
if (prevBtn) {
  prevBtn.addEventListener('click', () => {
    if (currentSessionId && currentBlockIndex > 0) {
      playBlock(currentSessionId, currentBlockIndex - 1);
    }
  });
}

if (nextBtn) {
  nextBtn.addEventListener('click', () => {
    if (currentSessionId) {
      const allBlocks = document.querySelectorAll('.clickable-block');
      if (currentBlockIndex + 1 < allBlocks.length) {
        playBlock(currentSessionId, currentBlockIndex + 1);
      }
    }
  });
}

// ================= DROPDOWNS (VELOCIDADE E VOZ) =================

// Velocidade Dropdown
if (speedBtn && speedDropdownMenu) {
  speedBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    speedDropdownMenu.classList.toggle('hidden');
    voiceDropdownMenu.classList.add('hidden'); // fecha o de voz
  });
}

speedOptions.forEach(opt => {
  opt.addEventListener('click', (e) => {
    e.stopPropagation();
    const speedVal = parseFloat(opt.getAttribute('data-speed'));
    currentSpeed = speedVal;
    
    // Atualiza label e player
    activeSpeedLabel.textContent = `${speedVal.toFixed(1).replace('.0', '')}x`;
    audioPlayer.playbackRate = speedVal;
    audioPlayer.defaultPlaybackRate = speedVal;

    // Atualiza classes
    speedOptions.forEach(o => o.classList.remove('active'));
    opt.classList.add('active');

    speedDropdownMenu.classList.add('hidden');
  });
});

// Voz Dropdown
if (voiceBtn && voiceDropdownMenu) {
  voiceBtn.addEventListener('click', (e) => {
    e.stopPropagation();
    voiceDropdownMenu.classList.toggle('hidden');
    speedDropdownMenu.classList.add('hidden'); // fecha o de velocidade
  });
}

function setupVoiceSelection() {
  const voiceOptions = document.querySelectorAll('.voice-option');
  voiceOptions.forEach(opt => {
    opt.onclick = (e) => {
      e.stopPropagation();
      const voiceId = opt.getAttribute('data-voice');
      const provider = opt.getAttribute('data-provider') || 'local';
      
      selectedVoiceId = voiceId;

      // Atualiza classes
      voiceOptions.forEach(o => o.classList.remove('active'));
      opt.classList.add('active');

      voiceDropdownMenu.classList.add('hidden');

      // Se estiver tocando, recarrega o bloco atual com a nova voz
      if (currentSessionId !== null && !audioPlayer.paused) {
        playBlock(currentSessionId, currentBlockIndex);
      }
    };
  });
}

// Inicializa a seleção de voz para os botões estáticos
setupVoiceSelection();

// Clique fora dos menus fecha-os
document.addEventListener('click', () => {
  if (speedDropdownMenu) speedDropdownMenu.classList.add('hidden');
  if (voiceDropdownMenu) voiceDropdownMenu.classList.add('hidden');
});


// ================= TEMA ESCURO / CLARO =================

if (themeToggleBtn) {
  themeToggleBtn.addEventListener('click', () => {
    const isDark = document.documentElement.classList.toggle('dark');
    document.body.classList.toggle('dark-mode-body', isDark);
  });
}
