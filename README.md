# workstation-bootstrap

Alan의 macOS + Ubuntu 개발 환경을 새 컴퓨터에 최대한 동일하게 재현하기 위한 **Init v2 / workstation bootstrap repo**입니다.

핵심 원칙은 이렇습니다.

- 이 repo는 **설정과 설치 manifest의 control plane**입니다.
- `Documents`, `Downloads`, `Workspace` 같은 대용량 사용자 데이터는 git에 넣지 않고, 외장 드라이브 루트의 sibling backup directory로 둡니다.
- terminal 환경은 현재 Mac과 동일하게 재현하는 것을 우선합니다.
- plaintext secret은 git에 넣지 않습니다. API key 값은 template render 시 환경변수/1Password/manual secret export로 주입합니다.
- Linux는 일단 **Ubuntu 24.04 LTS 계열**만 대상으로 검증합니다.

## 현재 자동화 범위

### macOS

- Homebrew common + full macOS Brewfile
- Mac App Store 앱: `packages/mas.darwin.txt`
  - paid/large GUI 앱 포함: Final Cut Pro, Logic Pro, Motion, Compressor, Xcode 등
- VS Code extensions: `packages/vscode-extensions.txt`
- language tools: npm/bun/uv/cargo manifests
- conservative macOS defaults
- chezmoi dotfiles

### Ubuntu

- apt native prerequisites: `packages/apt.ubuntu.txt`
- Linuxbrew common/CLI layer
- shared dotfiles where safe
- Docker Ubuntu dry-run smoke test

### Terminal parity

현재 Mac terminal 환경과 같아야 하는 파일을 repo에서 관리합니다.

- `~/.zshrc` → `dot_zshrc.tmpl`
- `~/.zshrc.alan` → `dot_zshrc.alan.tmpl`
- `~/.shell.alan` → `dot_shell.alan`
- `~/.tmux.conf` → `dot_tmux.conf`
- `~/.tmux.conf.local` → `dot_tmux.conf.local`
- `~/.gitconfig` → `dot_gitconfig`
- `~/.config/git/ignore` → `private_dot_config/git/ignore`
- `~/.vimrc` → `dot_vimrc`
- `~/.fzf.zsh` → `dot_fzf.zsh`
- `~/.gnupg/gpg-agent.conf` → `private_dot_gnupg/gpg-agent.conf.tmpl`
- `~/.ssh/config` and selected `~/.ssh/configs/*` → `private_dot_ssh/...`
- shell-adjacent dev defaults such as `~/.condarc`, `~/.clang-format`, and global git ignore

Oh My Zsh, Pure, zsh plugins, and TPM external dependencies are pinned in `.chezmoiexternal.toml` to the current source Mac commit IDs rather than floating on latest upstream.

Double-check:

```bash
just terminal-parity
```

이 검사는 현재 Mac의 home dotfiles와 repo에서 render되는 파일이 같은지 비교합니다. API key 값은 repo에 저장하지 않고 `OPENAI_API_KEY`, `GOOGLE_API_KEY`, `POLLINATIONS_API_KEY` 환경변수로 render됩니다.

## 새 Mac 설치 절차

### 0. 기존 머신에서 최종 점검

```bash
just inventory
just curate-inventory
just secret-scan
just verify
just terminal-parity
./bootstrap.sh --dry-run --tier full
```

외장 드라이브 백업도 dry-run으로 먼저 확인합니다.

```bash
just backup-plan DRIVE=/Volumes/<EmergencyDrive>
```

### 1. 새 Mac 기본 준비

1. macOS 설치/업데이트
2. Apple ID 로그인
3. Xcode Command Line Tools 준비
4. 1Password / SSH / GPG / cloud account 등 인증 준비
5. 이 repo clone

```bash
git clone <repo-url> ~/Workspace/src/Management/terminal
cd ~/Workspace/src/Management/terminal
```

### 2. secret env 준비

`~/.zshrc.alan`의 API key export line은 template이지만 plaintext key 값은 git에 없습니다. 완전히 같은 terminal env를 만들려면 apply 전에 환경변수를 채워야 합니다.

예시:

```bash
export OPENAI_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
export GOOGLE_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
export POLLINATIONS_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
```

1Password item 경로는 실제 vault 구조에 맞게 바꾸십시오. 당장 없으면 빈 값으로 render될 수 있으므로, terminal parity를 완전히 맞추려면 이 단계가 필요합니다.

### 3. dry-run 순서

```bash
./bootstrap.sh --dry-run --tier minimal
./bootstrap.sh --dry-run --tier cli
./bootstrap.sh --dry-run --tier full
chezmoi diff --source .
```

`chezmoi diff`에서 예상 밖의 credential/cache/app-state 파일이 나오면 중단합니다.

### 4. 실제 적용

최소/CLI부터 적용하고, full은 dry-run을 확인한 뒤 실행합니다.

```bash
./bootstrap.sh --tier minimal
./bootstrap.sh --tier cli
./bootstrap.sh --tier full
```

full tier는 VS Code extensions, MAS apps, casks까지 포함합니다. MAS 앱은 App Store 로그인과 라이선스 상태에 따라 수동 확인이 필요합니다.

### 5. 적용 후 검증

```bash
just verify
just terminal-parity
./bootstrap.sh --dry-run --tier full
```

그리고 직접 확인합니다.

```bash
zsh -lic 'echo $SHELL; type wrk; type codex; echo $GOPATH; git config --list --show-origin | sed -n "1,80p"'
tmux -f ~/.tmux.conf new-session -d -s bootstrap-check 'echo tmux-ok' && tmux kill-session -t bootstrap-check
code --list-extensions | sort | comm -23 packages/vscode-extensions.txt -
mas list
```

## Ubuntu 설치 절차

Ubuntu는 현재 24.04 LTS disposable VM/container dry-run 기준으로 검증합니다.

```bash
git clone <repo-url> ~/Workspace/src/Management/terminal
cd ~/Workspace/src/Management/terminal
./bootstrap.sh --dry-run --tier minimal
./bootstrap.sh --dry-run --tier cli
just verify
```

실제 Ubuntu 머신에서 non-dry-run은 disposable VM에서 먼저 확인한 뒤 진행하십시오.

## 외장 드라이브 emergency backup / restore

Repo는 외장 드라이브에도 clone/pull해서 sync합니다. 대용량 사용자 데이터는 repo 안이 아니라 외장 드라이브 root sibling directory에 둡니다.

권장 구조:

```text
/Volumes/<EmergencyDrive>/
├── .workstation-backup-drive.json
├── workstation-bootstrap/        # this repo clone/pull
├── Desktop/
├── Documents/
├── Downloads/
├── Workspace/
├── Pictures/
├── Movies/
├── Music/
├── Public/
└── _backup-meta/
```

Dry-run:

```bash
just backup-plan DRIVE=/Volumes/<EmergencyDrive>
```

Apply:

```bash
just backup-apply DRIVE=/Volumes/<EmergencyDrive>
```

Restore는 live home에 바로 덮지 않고 staging으로 갑니다.

```bash
just restore-plan DRIVE=/Volumes/<EmergencyDrive>
scripts/restore-user-dirs.sh --drive /Volumes/<EmergencyDrive> --apply --destination ~/Restore-Staging/YYYYMMDD
```

Safety:

- backup은 기본 dry-run입니다.
- marker file 없는 drive에는 apply하지 않습니다.
- `/`, `$HOME`, `$HOME` 내부, repo path는 backup destination으로 거부합니다.
- `rsync --delete`는 사용하지 않습니다.
- restore는 `--ignore-existing` + staging default입니다.

세부 내용: `docs/emergency-backup-layout.md`

## 주요 명령

```bash
just --list
just doctor
just audit
just curate-inventory
just inventory
just verify
just terminal-parity
just manifest-check
just backup-smoke
just secret-scan
just ubuntu-smoke
./bootstrap.sh --dry-run --tier full
```

## 검증 기준

신뢰 가능한 상태라고 말하려면 최소한 다음이 통과해야 합니다.

```bash
just secret-scan
just verify
just terminal-parity
test/smoke-bootstrap.sh
./bootstrap.sh --dry-run --tier full
just ubuntu-smoke
```

`brew bundle check`는 Brewfile syntax/manifest 확인에는 유용하지만, 현재 머신에 아직 설치되지 않은 항목이 있으면 unmet dependency로 실패할 수 있습니다. 이는 syntax failure와 구분해서 봐야 합니다.

## Stop conditions

다음이 보이면 적용을 멈추고 diff를 다시 봅니다.

- `just secret-scan` 실패
- `chezmoi diff --source .`에 Keychain/browser session/token/cache/private key가 나타남
- backup dry-run destination이 `/`, `$HOME`, repo root, marker 없는 drive로 나옴
- restore가 staging이 아니라 live home으로 직접 쓰려고 함
- macOS full dry-run에서 예상 밖의 app-state/database copy가 나옴
- Ubuntu dry-run이 Ubuntu 외 distro logic으로 흐름

## Repo layout

- `masterplan.md` — 전체 migration/bootstrap master plan
- `bootstrap.sh` — main entrypoint
- `packages/` — Homebrew, MAS, apt, VS Code, language-tool manifests
- `backup/` — user directory backup manifest/excludes
- `scripts/` — install/audit/backup/restore/verification scripts
- `.chezmoi*`, `dot_*`, `private_dot_*` — chezmoi source files
- `docs/` — migration, platform, backup, verification policy
- `test/` — smoke and safety tests
