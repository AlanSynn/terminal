# workstation-bootstrap

Alan의 macOS + Ubuntu 개발 환경을 새 컴퓨터에 재현하기 위한 **Init v2 / workstation bootstrap repo**입니다. 목표는 `oh-my-zsh`처럼 첫 명령이 자연스럽고, 필요하면 profile/tier/audit 옵션을 세밀하게 고를 수 있는 설치 흐름입니다.

> 현재 Linux 범위는 **Ubuntu 24.04 LTS 계열**입니다. Fedora/Arch/Nix는 의도적으로 보류합니다.

## 가장 빠른 시작

```bash
git clone <repo-url> ~/Workspace/src/Management/terminal
cd ~/Workspace/src/Management/terminal
./install.sh
```

`./install.sh`는 TTY에서는 메뉴를 띄우고, 기본값은 **dry-run preview**입니다. 실제 적용은 `APPLY`를 직접 입력하거나 `--yes`를 줘야 합니다.

자주 쓰는 흐름:

```bash
./install.sh --plan-only --tier cli             # 무엇을 할지 보기만 함
./install.sh --dry-run --tier cli               # 터미널/CLI 환경 preview
./install.sh --apply --tier minimal             # 최소 적용; 확인 프롬프트 있음
./install.sh --apply --tier full --yes          # 전체 적용; 비대화형 명시 승인
```

## 설치 선택지

### Profile

| Profile | 의미 |
| --- | --- |
| `personal` | 기본 개인 환경. 기본값. |
| `work` | work profile용 hook/data 자리. 현재는 보수적으로 유지. |
| `minimal` | 최소 dotfile/profile 렌더용. |
| `ci` | 검증/컨테이너 친화 경로. |

### Tier

| Tier | 포함 범위 |
| --- | --- |
| `minimal` | native prerequisites, Homebrew/Linuxbrew, common packages, chezmoi dotfiles, verify |
| `cli` | `minimal` + npm/bun/uv/cargo language tools. **추천 기본값** |
| `full` | `cli` + macOS GUI casks, MAS apps, VS Code extensions, OS defaults |
| `ci` | dry-run/container 검증 친화 경로 |

### Audit level

| Audit | 실행 내용 |
| --- | --- |
| `none` | installer preflight audit 생략 |
| `standard` | `scripts/verify-no-secrets.sh` + `just private-risk-audit`. 기본값 |
| `full` | standard + `just public-audit` |

예시:

```bash
./install.sh --dry-run --profile personal --tier full --audit full
./install.sh --apply --profile minimal --tier minimal --audit standard
./install.sh --dry-run --tier ci --audit none --yes
```

## 설치가 실제로 하는 일

`install.sh`는 UX wrapper입니다. 실제 작업은 계속 `bootstrap.sh`가 수행합니다.

1. preflight audit 선택 실행
2. `scripts/doctor.sh`
3. macOS CLT 또는 Ubuntu apt prerequisites
4. Homebrew/Linuxbrew 확인 또는 설치
5. tier별 package manifest 처리
6. `cli/full/ci`에서 language tools 처리
7. `full`에서 VS Code extensions 및 macOS GUI/MAS apps 처리
8. chezmoi diff/apply
9. macOS/Linux defaults
10. `scripts/verify-new-machine.sh`

직접 엔진을 호출할 수도 있습니다.

```bash
./bootstrap.sh --dry-run --profile personal --tier cli
./bootstrap.sh --profile personal --tier cli
```

## Terminal parity

현재 Mac terminal 환경과 같아야 하는 파일은 repo에서 관리합니다.

- zsh: `dot_zshrc.tmpl`, `dot_zshrc.alan.tmpl`, `dot_zshenv.tmpl`, `dot_shell.alan`
- tmux: `dot_tmux.conf`, `dot_tmux.conf.local`
- git/vim/fzf: `dot_gitconfig`, `dot_gitignore`, `dot_vimrc`, `dot_fzf.zsh`
- SSH/GPG agent config: `private_dot_ssh/...`, `private_dot_gnupg/gpg-agent.conf.tmpl`
- dev defaults: `dot_condarc`, `dot_clang-format`, selected config files

Oh My Zsh, Pure, zsh plugins, TPM 등 외부 dependency는 `.chezmoiexternal.toml`에 commit 기반으로 고정되어 있습니다.

확인:

```bash
just terminal-parity
```

API key 값은 git에 저장하지 않습니다. 완전한 terminal parity를 원하면 apply 전에 필요한 환경변수를 준비합니다.

```bash
export OPENAI_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
export GOOGLE_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
export POLLINATIONS_API_KEY="$(op read 'op://<vault>/<item>/<field>')"
```

## 안전장치와 중단 조건

최소 적용 전 확인:

```bash
scripts/verify-no-secrets.sh
just private-risk-audit
./install.sh --dry-run --tier cli
chezmoi diff --source .
```

멈춰야 하는 경우:

- secret scan 실패
- `chezmoi diff --source .`에 Keychain/browser session/token/cache/private key가 나타남
- `just private-risk-audit`의 HIGH 항목을 이해/수용하지 못함
- backup dry-run destination이 `/`, `$HOME`, repo root, marker 없는 drive로 나옴
- restore가 staging이 아니라 live home으로 직접 쓰려고 함
- macOS `full` dry-run에서 예상 밖의 app-state/database copy가 보임
- Ubuntu dry-run이 Ubuntu 외 distro logic으로 흐름

## Emergency external-drive backup

Repo는 외장 드라이브에도 clone/pull해서 sync합니다. 대용량 사용자 데이터는 repo 안이 아니라 외장 드라이브 root sibling directory에 둡니다.

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

Restore는 live home이 아니라 staging이 기본입니다.

```bash
just restore-plan DRIVE=/Volumes/<EmergencyDrive>
scripts/restore-user-dirs.sh --drive /Volumes/<EmergencyDrive> --apply --destination ~/Restore-Staging/YYYYMMDD
```

자세한 내용: `docs/emergency-backup-layout.md`

## 주요 명령

```bash
just --list
just install
just doctor
just verify
just installer-smoke
just terminal-parity
just private-risk-audit
just public-audit
just manifest-check
just backup-smoke
just ubuntu-smoke
```

## Repo surface: 무엇이 필요한가?

요약:

- **핵심 유지:** `install.sh`, `bootstrap.sh`, `Justfile`, `packages/`, `scripts/install-*`, `scripts/verify-*`, `.chezmoi*`, terminal dotfiles, backup/restore scripts.
- **고급/정책 문서로 유지:** security/public/private/readiness/backup docs.
- **레거시이지만 당장 삭제하지 않음:** `masterplan.md`, `scripts/sanitize-import.sh`, `import-init*` recipes. Init provenance와 재-import 안전장치라 quick start에서는 숨기되 보존합니다.
- **미래 cleanup 후보:** Nix phase note, 너무 작은 platform docs, import-init tooling은 bootstrap이 실제 머신에서 충분히 검증된 뒤 archive/remove 여부 결정.

자세한 검토: `docs/repo-surface-review.md`

## Repo layout

- `install.sh` — friendly first-run installer wrapper
- `bootstrap.sh` — deterministic bootstrap engine
- `packages/` — Homebrew, MAS, apt, VS Code, language-tool manifests
- `backup/` — user directory backup manifest/excludes
- `scripts/` — install/audit/backup/restore/verification scripts
- `.chezmoi*`, `dot_*`, `private_dot_*` — chezmoi source files
- `docs/` — platform, backup, security, verification, cleanup policy
- `masterplan.md` — historical Init v2 planning record, not the first-run guide
