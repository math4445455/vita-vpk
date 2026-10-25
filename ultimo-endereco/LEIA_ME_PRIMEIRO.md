# O ÚLTIMO ENDEREÇO — Port para PlayStation Vita

**Edição de código e conteúdo adaptados para PS Vita / PlayStation TV, versão 1.0 (experimental).**

Esta pasta contém o jogo original do PSP Go **portado para a API do Lua Player Plus Vita (LPP-Vita)**, e não apenas os arquivos antigos renomeados. A aventura completa, os 54 cenários, 36 puzzles, seis distritos, diálogos, três finais e seis músicas foram preservados. O port prepara a renderização na tela **960 × 544 (escala exata de 2×)**, os controles e os caminhos de salvamento do Vita. As imagens conservam o estilo visual da versão PSP: não se trata de um redesenho em alta resolução.

## O que falta para instalar

**O ZIP entregue é o port completo de código/assets, MAS NÃO é um `.vpk` pronto para instalação.** Para criar o arquivo `.vpk`, é necessário obter o **executável nativo oficial do LPP-Vita** (`eboot_safe.bin`) separadamente. Esse binário **não acompanha** o ZIP. **Não use o `EBOOT.PBP` do PSP**, pois ele é de outra arquitetura e não funciona como executável nativo do Vita.

O script `build_vpk.py` combina o runtime oficial do Vita, o port completo, o ícone e o LiveArea, criando uma bolha própria com o ID `ULTMEND01`.

## Gerar o .vpk no computador (Windows / Linux / macOS)

1. Instale Python 3 no computador (caso ainda não tenha).
2. Baixe o Lua Player Plus Vita na página **OFICIAL**, preferencialmente a opção segura (`eboot_safe.bin`):
   https://github.com/Rinnegatamante/lpp-vita/releases/tag/Nightly
3. Extraia este ZIP para uma pasta. Extraia também o `.zip` da release oficial do LPP-Vita, se necessário, até encontrar `eboot_safe.bin`. **Não instale nem execute um arquivo de origem duvidosa.**
4. No Windows, você pode **arrastar o arquivo `eboot_safe.bin` para cima de `GERAR_VPK_WINDOWS.bat`**, ou dar dois cliques no `.bat` e inserir o caminho solicitado. Alternativamente, abra um terminal nesta pasta e execute:

   ```sh
   python build_vpk.py "C:/Users/VOCE/Downloads/eboot_safe.bin"
   ```

   Em algumas instalações do Windows use `py -3` no lugar de `python`.

5. O script cria **`O_ULTIMO_ENDERECO_VITA.vpk`** nesta mesma pasta. Também é possível fornecer o **VPK original do LPP-Vita** como argumento, desde que ele contenha `eboot.bin` nativo e `sce_sys/param.sfo`.
6. Transfira o VPK resultante para o Vita com FTP/USB; por exemplo, deixe-o em `ux0:/data/O_ULTIMO_ENDERECO_VITA.vpk`.
7. Num **Vita preparado para executar homebrew**, abra **VitaShell**, selecione o VPK, instale-o e depois abra a bolha **O ÚLTIMO ENDEREÇO** na tela inicial.

**Importante:** não é necessário instalar o Lua Player Plus Vita como outro aplicativo; o executável fornecido no passo 2 é incluído no jogo quando o VPK é montado. Para instalar o VPK, o Vita precisa estar configurado para homebrew. Este tutorial não modifica o firmware do console.

## Controles do PlayStation Vita

- **Direcional ou analógico esquerdo:** andar.
- **Segurar ○:** correr durante a exploração.
- **×:** examinar, conversar, confirmar.
- **△:** abrir bolsa.
- **□:** abrir diário; na bolsa, selecionar dois objetos para combinar.
- **SELECT:** mapa da região atual.
- **START:** menu de pausa, salvar, música e viagem entre distritos visitados.
- **Dentro dos puzzles:** △ testa a resposta; **R** mostra dicas; **L** reinicia; **○** volta. Alguns puzzles usam **□** para desfazer/remover.

## Saves e migração do PSP Go

O Vita salva em **`ux0:/data/ULTIMOEND/`**, usando os arquivos **`progresso_a.sav`** e **`progresso_b.sav`** de forma alternada. Para continuar sua campanha do PSP Go, copie esses dois arquivos do diretório original `PSP/GAME/ULTIMOEND/` para essa pasta do Vita (faça backup primeiro). Se a pasta ainda não existir, crie-a ou abra o jogo uma vez.

Para evitar perda de progresso, **não exclua `ux0:/data/ULTIMOEND/`** ao reinstalar o aplicativo. Use START > Salvar e sair antes de encerrar.

## Testes e limites conhecidos

O código Lua foi verificado sintaticamente e a simulação de ambiente Vita em computador executou a inicialização e dezenas de milhares de operações de desenho, exercitando menus, mundo, puzzles e progresso. **Ainda NÃO houve execução em um PS Vita físico ou no Vita3K, nem um teste real da instalação do VPK final**, que depende do binário oficial ausente neste ambiente. Compatibilidade final, áudio, save e desempenho real precisam ser confirmados no console. Este é um **port experimental**, não uma promessa de funcionamento perfeito.

- O jogo é **nativo Vita** somente após o empacotamento com o runtime LPP-Vita; **não usa Adrenaline**.
- A API de áudio aceita `.ogg`, mas diferenças de versão do LPP podem causar variações.
- Os cenários foram preservados com escala 2× de pixels (sem refazer as artes).
- Se o `build_vpk.py` rejeitar um arquivo com o erro “não parece um executável nativo”, provavelmente você forneceu um `EBOOT.PBP` de PSP ou um runtime não compatível. Use **`eboot_safe.bin` de LPP-Vita**.
- Se aparecer erro ao executar o jogo, fotografe a tela com o texto completo para diagnosticar precisamente. Uma tela de erro é preferível a desligamentos silenciosos.

## Estrutura para desenvolvimento

```
APP_VITA/
  index.lua           entrada do jogo nativo Vita
  vita_compat.lua     adaptadores LPP-Vita (Graphics, Screen, Controls, Timer, Sound)
  game.lua            interface, exploração, puzzles e fluxo da história
  logic.lua           regras dos 36 puzzles, progressão e salvamentos
  data/content.lua   narrativa e dados das 54 salas
  assets/             sprites, fontes e 54 mapas
  audio/              seis temas OGG
SCE_SYS_VITA/         ícone, imagem e LiveArea
build_vpk.py          cria o VPK a partir do binário oficial do LPP-Vita
GERAR_VPK_WINDOWS.bat assistente para Windows
TESTES/               simulador de APIs para teste de fumaça
GUIAS/                guia de puzzles com spoilers
LICENCAS/             documentação de créditos e licenças
```

## Créditos, fontes e licenças

O conteúdo, a narrativa e as artes são os da edição original **O Último Endereço** fornecida para PSP Go. O port reutiliza seus dados sem criar uma obra oficial da Sony ou de OneShot. O **Lua Player Plus Vita**, mantido por **Rinnegatamante e colaboradores**, está disponível sob **GPLv3**: https://github.com/Rinnegatamante/lpp-vita . O runtime **não foi redistribuído neste ZIP**; obtenha-o na fonte oficial e respeite as condições da licença se redistribuir um VPK que o inclua. Licenças e atribuições adicionais da edição PSP estão em `LICENCAS/`.
