#!/usr/bin/env bash
#
# Incrementa automaticamente a versão (pkgver) do PKGBUILD.
#
# Uso:
#   ./bump-version.sh                 # 1.0.2 -> 1.0.3 (patch)
#   ./bump-version.sh minor           # 1.0.2 -> 1.1.0
#   ./bump-version.sh major           # 1.0.2 -> 2.0.0
#   ./bump-version.sh set 3.2.1       # define uma versão específica
#   ./bump-version.sh --commit --tag  # atualiza, commita e cria a tag vX.Y.Z
#   ./bump-version.sh --push          # também envia commit e tag para o remoto

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PKGBUILD="$SCRIPT_DIR/PKGBUILD"

usage() {
	cat <<'EOF'
Uso: ./bump-version.sh [major|minor|patch] [opções]
       ./bump-version.sh set <versão> [opções]

Incrementa o pkgver do PKGBUILD e zera o pkgrel.

Opções:
  --commit   Cria um commit com a mudança de versão
  --tag      Cria a tag anotada vX.Y.Z (requer --commit)
  --push     Envia o commit e a tag para o remoto (requer --tag)
  --dry-run  Mostra o que seria feito, sem alterar nada
  -h, --help Mostra esta ajuda
EOF
}

part="patch"
explicit_version=""
do_commit=false
do_tag=false
do_push=false
dry_run=false

while (($#)); do
	case "$1" in
		major | minor | patch)
			part="$1"
			;;
		set)
			shift
			if (($# == 0)); then
				echo "Erro: informe a versão após 'set'." >&2
				exit 1
			fi
			explicit_version="$1"
			;;
		--commit) do_commit=true ;;
		--tag) do_tag=true ;;
		--push) do_push=true ;;
		--dry-run) dry_run=true ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "Opção inválida: $1" >&2
			usage >&2
			exit 1
			;;
	esac
	shift
done

if [[ ! -f "$PKGBUILD" ]]; then
	echo "Erro: PKGBUILD não encontrado em $SCRIPT_DIR." >&2
	exit 1
fi

if $do_tag && ! $do_commit; then
	echo "Erro: --tag exige --commit." >&2
	exit 1
fi

if $do_push && ! $do_tag; then
	echo "Erro: --push exige --tag (e --commit)." >&2
	exit 1
fi

if $do_tag; then
	# A tag deve apontar para um commit que contenha exatamente o código a ser lançado.
	if [[ -n "$(git -C "$SCRIPT_DIR" status --porcelain -- . ':(exclude)PKGBUILD')" ]]; then
		echo "Erro: existem alterações não commitadas fora do PKGBUILD." >&2
		echo "Commit ou descarte essas alterações antes de criar a tag." >&2
		exit 1
	fi
fi

current_version="$(sed -n 's/^pkgver=//p' "$PKGBUILD" | head -n1)"

if [[ -z "$current_version" ]]; then
	echo "Erro: não foi possível encontrar 'pkgver=' no PKGBUILD." >&2
	exit 1
fi

if [[ ! "$current_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
	echo "Erro: pkgver atual '$current_version' não é numérico (esperado algo como 1.2.3)." >&2
	exit 1
fi

if [[ -n "$explicit_version" ]]; then
	if [[ ! "$explicit_version" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
		echo "Erro: versão inválida '$explicit_version' (esperado algo como 1.2.3)." >&2
		exit 1
	fi
	new_version="$explicit_version"
else
	IFS='.' read -r -a version_parts <<<"$current_version"

	while ((${#version_parts[@]} < 3)); do
		version_parts+=(0)
	done

	major="${version_parts[0]}"
	minor="${version_parts[1]}"
	patch="${version_parts[2]}"

	case "$part" in
		major)
			major=$((major + 1))
			minor=0
			patch=0
			;;
		minor)
			minor=$((minor + 1))
			patch=0
			;;
		patch)
			patch=$((patch + 1))
			;;
	esac

	new_version="$major.$minor.$patch"
fi

if [[ "$new_version" == "$current_version" ]] && ! $do_commit && ! $do_tag && ! $do_push; then
	echo "A versão já é $new_version. Nada a fazer."
	exit 0
fi

echo ":: Versão: $current_version -> $new_version"

if $dry_run; then
	echo "[dry-run] PKGBUILD não foi alterado."
	exit 0
fi

sed -i \
	-e "s/^pkgver=.*/pkgver=$new_version/" \
	-e "s/^pkgrel=.*/pkgrel=1/" \
	"$PKGBUILD"

# Mantém o .SRCINFO sincronizado quando ele existir (necessário para o AUR).
if [[ -f "$SCRIPT_DIR/.SRCINFO" ]] && command -v makepkg >/dev/null 2>&1; then
	(cd "$SCRIPT_DIR" && makepkg --printsrcinfo >.SRCINFO)
fi

if $do_commit; then
	git -C "$SCRIPT_DIR" add PKGBUILD
	if [[ -f "$SCRIPT_DIR/.SRCINFO" ]]; then
		git -C "$SCRIPT_DIR" add .SRCINFO
	fi
	if ! git -C "$SCRIPT_DIR" diff --cached --quiet; then
		git -C "$SCRIPT_DIR" commit -m "chore(release): v$new_version"
	else
		echo "Nenhuma alteração pendente para commitar."
	fi
fi

if $do_tag; then
	if git -C "$SCRIPT_DIR" rev-parse -q --verify "refs/tags/v$new_version" >/dev/null; then
		echo "Erro: a tag v$new_version já existe." >&2
		exit 1
	fi
	git -C "$SCRIPT_DIR" tag -a "v$new_version" -m "v$new_version"
fi

if $do_push; then
	git -C "$SCRIPT_DIR" push origin HEAD
	git -C "$SCRIPT_DIR" push origin "v$new_version"
fi

echo "=> Versão atualizada para $new_version."

if ! $do_commit; then
	echo "Próximo passo: revise o PKGBUILD e rode './bump-version.sh set $new_version --commit --tag --push' para lançar."
elif ! $do_tag; then
	echo "Próximo passo: crie a tag com 'git tag -a v$new_version -m \"v$new_version\"' e envie com 'git push origin v$new_version'."
elif ! $do_push; then
	echo "Próximo passo: envie com 'git push origin HEAD && git push origin v$new_version'."
fi
