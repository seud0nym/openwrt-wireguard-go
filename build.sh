#!/bin/sh

BASE_DIR="$(pwd)"
REPO_ROOT_DIR="$(dirname $(pwd))"

GREEN='\033[1;32m'
GREY='\033[90m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# https://golang.org/doc/install/source#environment
GOARCH_ALL="386 amd64 arm arm64 ppc64 ppc64le mips mipsle mips64 mips64le riscv64 s390x"

if [ $# -eq 0 ]; then
    set -- "arm"
elif [ "$1" = "all" ]; then
    set -- $GOARCH_ALL
else
    for a in $@; do
        if ! echo "$a" | grep -qE "\b${a}\b"; then
            echo "${RED}:ERROR: Unknown architecture '$a'!${NC}"
            echo "        Valid values are: ${GREEN}$GOARCH_ALL${NC}"
            exit 2
        fi
    done
fi

gitreset() {
    git fetch
    git reset --hard HEAD
    git merge '@{u}'
}

checkSHA256() {
    local FILE="$1"
    local EXPECTED="$2"
    
    local CALCULATED="$(sha256sum $FILE | cut -d' ' -f1)"

    if [ "$CALCULATED" != "$EXPECTED" ]; then
        echo "${RED}:ERROR: Checksum mismatch on $FILE!!${NC}"
        echo "   Expecting  ${GREEN}$EXPECTED${NC}"
        echo "   Calculated ${ORANGE}$CALCULATED${NC}"
        return 1
    else
        return 0
    fi
}

wireguard() {
    echo "${GREEN}:Processing wireguard-go${GREY}"
    local UNMODIFIED_main="1889250813d3fc9e4538e669b4fe86fd2caa4949094be06033e6a5c0eb6deb29"
    local UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
    local UNMODIFIED_queueconstants_default="461802f0fac24977a6164ac96b47b59740c506ed124c39a9e434493889384f28"
    
    local MODIFIED_main="2cf3bcb37be0f4e4e58ccc416ba16a6bec61261f12271afa7c9aedceacf51589"
    local MODIFIED_makefile="c04d9998ae41f016319fb49cc7ffe4955c016368b880814980335fce48b961a2"
    local MODIFIED_queueconstants_default="228c3ed2e4851c988d6a0e4837d18d26f32880331beaa723f13d9aa27dd2be51"

    cd ${REPO_ROOT_DIR}
    if [ ! -d wireguard-go ]; then
        git clone https://git.zx2c4.com/wireguard-go
    fi

    cd ${REPO_ROOT_DIR}/wireguard-go
    echo "${GREEN} -> Pulling latest wireguard-go repository...${GREY}"
    gitreset

    if checkSHA256 main.go $UNMODIFIED_main && checkSHA256 device/queueconstants_default.go $UNMODIFIED_queueconstants_default; then
        echo "${GREEN} -> Removing 'first class kernel support' intercept from main.go...${GREY}"
        sed -e '/warning()$/d' -i main.go
        echo "${GREEN} -> Modifying device/queueconstants_default.go to minimize memory use...${GREY}" # https://d.sb/2019/07/wireguard-on-openvz-lxc
        sed -e 's/\(MaxSegmentSize *=\).*/\1 1700/' -e 's/\(PreallocatedBuffersPerPool =\).*/\1 1024/' -i device/queueconstants_default.go
        echo "${GREEN} -> Modifying Makefile...${GREY}"
        sed -e 's/\(go build -v\)/\1 -ldflags "-s -w"/' -i Makefile
        git update-index --assume-unchanged device/queueconstants_default.go
        echo -n "${NC}"
        if checkSHA256 main.go $MODIFIED_main && checkSHA256 device/queueconstants_default.go $MODIFIED_queueconstants_default && checkSHA256 Makefile $MODIFIED_makefile; then
            return 0
        fi
        return 1
    fi

    return 1
}

wg() {
    echo "${GREEN}:Processing wg-go${GREY}"

    cd ${REPO_ROOT_DIR}
    if [ ! -d wg-go ]; then
        git clone https://github.com/seud0nym/wg-go.git
    fi

    cd ${REPO_ROOT_DIR}/wg-go
    if [ -n "$(git diff)" ]; then
        echo "${RED}:ERROR: Uncommited changes in wg-go repository${NC}"
        return 1
    fi

    return 0
}

build_release() {
    local tgz="$(basename $BASE_DIR)_$1.tgz" 

    local source
    local target
    local filename

    echo "${GREEN}:Creating release asset $tgz...${GREY}"
    for source in "$REPO_ROOT_DIR/wireguard-go/wireguard-go" "$REPO_ROOT_DIR/wg-go/wg-go"; do
        cd "$(dirname "$source")"
        filename="$(basename $source)"
        echo "${GREEN} -> Building $filename...${GREY}"
        make
        target="$BASE_DIR/release/usr/bin/$filename"
        if ! cmp "$source" "$target" 2>/dev/null; then
            mv "$source" "$target"
        else
            rm "$source"
        fi
    done

    echo "${GREEN} -> Building $BASE_DIR/$tgz...${GREY}"
    tar -zvcf $BASE_DIR/$tgz --mode=755 --exclude="*.git*" -C "$BASE_DIR/release" $(find "$BASE_DIR/release" -maxdepth 1 -type d ! -name . -printf "%P ")
    echo -n "${NC}"
}

if wg && wireguard; then
    echo "${GREY}"
    if ! cmp "$REPO_ROOT_DIR/wg-go/wg" "$BASE_DIR/release/usr/bin/wg" 1>&2 2>/dev/null; then
        echo "${GREEN}:Updating $BASE_DIR/release/usr/bin/wg...${GREY}"
        cp -p "$REPO_ROOT_DIR/wg-go/wg" "$BASE_DIR/release/usr/bin/wg"
        echo -n "${NC}"
    fi

    cd $BASE_DIR

    export GOOS="linux"
    for a in $@; do
        export GOARCH="$a"
        if [ "$a" = "arm" ]; then
            for v in 5 6 7; do
                export GOARM="$v"
                build_release "${a}v${v}"
                unset GOARM
            done
        else
            build_release "$a"
        fi
        unset GOARCH
    done
    unset GOOS

    for f in wg wg-go wireguard-go; do
        [ -e "$BASE_DIR/release/usr/bin/$f" ] && rm "$BASE_DIR/release/usr/bin/$f"
    done
fi

