# O Último Endereço no PlayStation Vita — gerar VPK usando GitHub Actions

Este pacote contém **todos os arquivos do port Vita** e um workflow do GitHub Actions
que baixa o **`eboot_safe.bin` oficial do Lua Player Plus Vita**, executa testes
de sintaxe e gera automaticamente **`O_ULTIMO_ENDERECO_VITA.vpk`**.

## Usar com seu repositório `velocity-rush-vita`

Este pacote **não substitui nem altera o jogo Velocity Rush**; o código novo
fica exclusivamente na pasta `ultimo-endereco/` e usa um workflow com nome próprio.
Como não conseguimos ler esse repositório publicamente, não editamos o seu GitHub.

1. No PC, extraia `O_ULTIMO_ENDERECO_GITHUB_ACTIONS.zip`.
2. Abra o repositório `math4445455/velocity-rush-vita` usando **GitHub Desktop**:
   File > Clone repository (ou abra a cópia local que já possui).
3. Copie **a pasta `ultimo-endereco` e a pasta `.github`** do ZIP para a raiz da cópia
   local do repositório. Se já houver `.github`, **mescle as pastas**, sem substituir
   os arquivos antigos. A nova ação se chama
   `.github/workflows/gerar-vpk-ultimo-endereco.yml`.
4. No GitHub Desktop, faça um commit com mensagem
   `Adiciona port O Ultimo Endereco e workflow para VPK` e escolha **Push origin**.
5. Entre na aba **Actions** do repositório, selecione
   **Gerar VPK - O Ultimo Endereco (PS Vita)**, clique **Run workflow**.
   Também executa automaticamente quando houver push dos arquivos desta pasta
   na branch main/master.
6. Quando o job terminar com sinal verde, abra-o na aba Actions. Na seção
   **Artifacts** ao fim da página, baixe **`O_ULTIMO_ENDERECO_VITA_VPK`**.
   Extraia o ZIP de artifact: dentro estará **`O_ULTIMO_ENDERECO_VITA.vpk`**.
7. Copie o `.vpk` para seu Vita, abra o **VitaShell** e instale.

**Alternativa:** use estes arquivos em um **novo repositório** se não quiser
misturar dois jogos. Mantenha a mesma estrutura de pastas da raiz.

## Observações e limites

- **O ZIP que acompanha estas instruções não é o VPK.** O arquivo VPK será
  construído nos servidores do GitHub após você executar o workflow.
- O binário baixado é do repositório oficial:
  `https://github.com/Rinnegatamante/lpp-vita/releases/tag/Nightly`.
- O workflow verifica o SHA-256 da edição disponibilizada em **18/12/2025**:
  `6ab6a6e39d32143a4e031d7072090dc34786be91e11e8f5d5edd75c098489930`.
  Se o mantenedor publicar uma nova edição no mesmo link, o teste de checksum
  falhará de propósito. Nesse caso atualize a soma somente após confirmar
  o novo binário oficial.
- Não é o executável de PSP renomeado: o VPK combina uma camada Lua nativa Vita
  com as imagens, o áudio e a história portados do jogo original.
- A estrutura ZIP, os scripts Lua, os assets, o Title ID e a criação do
  VPK são verificados automaticamente. **O jogo não foi executado/testado em
  um PS Vita real.** Isso ainda pode revelar bugs de runtime, áudio e salvamento.
- Distribuição pública do VPK deve respeitar a licença GPLv3 do LPP-Vita
  e as licenças/autorizações de todos os outros componentes.

## Se falhar

Copie ou fotografe o erro do job vermelho na aba **Actions** ou envie o erro
exibido no console. Se travar no Vita, informe o que apareceu na tela.
