#!/bin/bash

BASE_DIR="$(pwd)"
REPO_ROOT_DIR="$(dirname $(pwd))"

GREEN='\033[1;32m'
GREY='\033[90m'
ORANGE='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# https://golang.org/doc/install/source#environment
GOARCH_ALL="386 amd64 arm arm64 ppc64 ppc64le mips mipsle mips64 mips64le riscv64 s390x mipsel_24kc"

COMMIT="HEAD"
ARM=""

while getopts :a:c: option; do
  case "${option}" in
    a)  case "$OPTARG" in 5|6|7) ARM="$ARM $OPTARG";; *) echo -e "${RED}ERROR: Unsupported ARM version $OPTARG${NC}"; exit 2;; esac;;
    c)  COMMIT="$OPTARG";;
    *)  echo -e "${RED}ERROR: Unknown option -${OPTION}${NC}"; exit 2;;
  esac
done
shift $((OPTIND-1))

[ -z "$ARM" ] && ARM="7 6 5"

if [ $# -eq 0 ]; then
  set -- "arm arm64 mips"
elif [ "$1" = "all" ]; then
  set -- $GOARCH_ALL
else
  for a in $@; do
    if ! echo "$GOARCH_ALL" | grep -qE "\b${a}\b"; then
      echo -e "${RED}ERROR: Unknown architecture '$a'!${NC}"
      echo -e "        Valid values are: ${GREEN}$GOARCH_ALL${NC}"
      exit 2
    fi
  done
fi

if [ ! -x bin/usign ]; then
  echo -e "${GREEN}:Building usign...${GREY}${NC}"
  git submodule init
  git submodule update
  pushd usign || exit 2
    git fetch
    git gc
    git reset --hard HEAD
    git merge origin/master
    rm -rf build
    mkdir build
    pushd build
      echo -e "${GREEN} -> Generating build system for usign...${GREY}${NC}"
      cmake ..
      echo -e "${GREEN} ->  Building usign...${GREY}${NC}"
      make --silent || exit 2
    popd # build
  popd # usign
  cp usign/build/usign bin/usign
fi

[ -e keys/seud0nym-private.key ] || { echo -e "${RED}ERROR: Private key not found!${NC}"; exit 2; }

echo -e "${GREEN}:Determining latest upx version...${NC}"
__UPX_URL=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/upx/upx/releases/latest)
__UPX_VER=$(basename $__UPX_URL | sed -e 's/^v//')
if [ ! -x bin/upx -o "$(bin/upx -V 2>/dev/null | grep ^upx | grep -o '[0-9.]*')" != "$__UPX_VER" ]; then
  curl -L https://github.com/upx/upx/releases/download/v${__UPX_VER}/upx-${__UPX_VER}-amd64_linux.tar.xz -o /tmp/upx.tar.xz
  if [ -e /tmp/upx.tar.xz ]; then
    tar -C bin --strip-components=1 -xJf /tmp/upx.tar.xz upx-${__UPX_VER}-amd64_linux/upx
    rm -rf /tmp/upx.tar.xz
  else
    echo -e "${RED} -> ERROR: Failed to download upx v${__UPX_VER}!${NC}"
    exit 2
  fi
fi

gitreset() {
  local version
  git fetch
  git gc
  git reset
  git reset --hard $COMMIT || exit 2
  if [ "$COMMIT" = "HEAD" ]; then
    git merge '@{u}'
    git reset --hard origin/master
    git fetch --tags
    version=$(git describe --tags `git rev-list --tags --max-count=1`)
    git config --add advice.detachedHead false
    git checkout $version
  fi
}

checkSHA256() {
  local FILE="$1"
  local EXPECTED="$2"
  
  local CALCULATED="$(sha256sum $FILE | cut -d' ' -f1)"

  if [ "$CALCULATED" != "$EXPECTED" ]; then
    echo -e "${RED}:ERROR: Checksum mismatch on $FILE!!${NC}"
    echo -e "   Expecting  ${GREEN}$EXPECTED${NC}"
    echo -e "   Calculated ${ORANGE}$CALCULATED${NC}"
    return 1
  else
    return 0
  fi
}

wireguard() {
  echo -e "${GREEN}:Processing wireguard-go${GREY}"
  local UNMODIFIED_main="b8d2b095b7de82d613b89553215879b810a6d2481459b80c83dc4328625d9e31"
  local UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
  local UNMODIFIED_queueconstants_default="c8d7dc22378554d8003ffbeb7c45fc0144cd9f691d17e6c60939fae4c829c411"
  
  local MODIFIED_main="d035abc337850ccc8c59abffa1e32c0556d26d89a12caaf51548ea0712e88523"
  local MODIFIED_makefile="0b650215e15b92e0b185fc56bc517390cb35e1d36af0dea09920b84c568065c1"
  local MODIFIED_queueconstants_default="9fcf4a4cab866c4ceb9bb88a84ab708838e2e53904c8e3d599dcc03a5b5e9675"

  cd ${REPO_ROOT_DIR}
  if [ ! -d wireguard-go ]; then
    git clone https://git.zx2c4.com/wireguard-go
  fi

  cd ${REPO_ROOT_DIR}/wireguard-go
  if [ $COMMIT = HEAD ]; then
    echo -e "${GREEN} -> Pulling latest wireguard-go repository...${GREY}"
  else
    echo -e "${GREEN} -> Pulling wireguard-go repository as at commit ${COMMIT}...${GREY}"
  fi
  gitreset

  [ -z "$VERSION" ] && VERSION=$(date +%Y.%m.%d)

  case $(git rev-parse --short HEAD) in
    2163620) # wireguard v0.0.20230223
      VERSION="2023.09.29"
      UNMODIFIED_main="b8d2b095b7de82d613b89553215879b810a6d2481459b80c83dc4328625d9e31"
      UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
      UNMODIFIED_queueconstants_default="c8d7dc22378554d8003ffbeb7c45fc0144cd9f691d17e6c60939fae4c829c411"
      MODIFIED_main="d035abc337850ccc8c59abffa1e32c0556d26d89a12caaf51548ea0712e88523"
      MODIFIED_makefile="0b650215e15b92e0b185fc56bc517390cb35e1d36af0dea09920b84c568065c1"
      MODIFIED_queueconstants_default="9fcf4a4cab866c4ceb9bb88a84ab708838e2e53904c8e3d599dcc03a5b5e9675"
      ;;
    7aeaee6)
      VERSION="2022.10.29"
      UNMODIFIED_main="9ed8dfb5048293a4b7e8fa4e8bf697f06689f412346964f76b1381cb9ca52f79"
      UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
      UNMODIFIED_queueconstants_default="0e2637fc857d46ec3dfb0600360f4ebbb356982b729c23932283032bab887c7a"
      MODIFIED_main="20f6d2b8ede9759ce3292bf1068975ec55c9b118aebecfa6637b25a4dab8e236"
      MODIFIED_makefile="0b650215e15b92e0b185fc56bc517390cb35e1d36af0dea09920b84c568065c1"
      MODIFIED_queueconstants_default="92cff3d85807a6719f998b3a3b01a48840dbadf8c1b472d6001cb563dd857762"
      ;;
    d49a3de)
      VERSION="2022.08.20"
      UNMODIFIED_main="8c58063f67f63d91d64dec6072cf728a3449a1b263c99074c850db0a630f6058"
      UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
      UNMODIFIED_queueconstants_default="470364f455a6637f061cf6363929e8977f7872b43fd6f5ea008e223671b5330c"
      MODIFIED_main="18c2174e0a22c3e9ac6fd5d077ed8e7e97ec401f3207bf45e5b590964fc4ace4"
      MODIFIED_makefile="0b650215e15b92e0b185fc56bc517390cb35e1d36af0dea09920b84c568065c1"
      MODIFIED_queueconstants_default="7a7fdce9ae60633d82c54749edffffa4de9a30f0352009a11383c30d8c2654b3"
      ;;
    3b95c81)
      VERSION="2022.03.01"
      UNMODIFIED_main="8c58063f67f63d91d64dec6072cf728a3449a1b263c99074c850db0a630f6058"
      UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
      UNMODIFIED_queueconstants_default="470364f455a6637f061cf6363929e8977f7872b43fd6f5ea008e223671b5330c"
      MODIFIED_main="18c2174e0a22c3e9ac6fd5d077ed8e7e97ec401f3207bf45e5b590964fc4ace4"
      MODIFIED_makefile="0b650215e15b92e0b185fc56bc517390cb35e1d36af0dea09920b84c568065c1"
      MODIFIED_queueconstants_default="7a7fdce9ae60633d82c54749edffffa4de9a30f0352009a11383c30d8c2654b3"
      ;;
    bb745b2)
      VERSION="2021.11.27"
      UNMODIFIED_main="1889250813d3fc9e4538e669b4fe86fd2caa4949094be06033e6a5c0eb6deb29"
      UNMODIFIED_makefile="f59c6fbbe54c2d194207ef93bdb27ab69a4f67efd26f147f3a0c60268ebaf57c"
      UNMODIFIED_queueconstants_default="461802f0fac24977a6164ac96b47b59740c506ed124c39a9e434493889384f28"
      MODIFIED_main="2cf3bcb37be0f4e4e58ccc416ba16a6bec61261f12271afa7c9aedceacf51589"
      MODIFIED_makefile="c04d9998ae41f016319fb49cc7ffe4955c016368b880814980335fce48b961a2"
      MODIFIED_queueconstants_default="228c3ed2e4851c988d6a0e4837d18d26f32880331beaa723f13d9aa27dd2be51"
      ;;
  esac

  if checkSHA256 main.go $UNMODIFIED_main && checkSHA256 device/queueconstants_default.go $UNMODIFIED_queueconstants_default; then
    echo -e "${GREEN} -> Removing 'first class kernel support' intercept from main.go...${GREY}"
    sed -e '/warning()$/d' -i main.go
    echo -e "${GREEN} -> Modifying device/queueconstants_default.go to minimize memory use...${GREY}" # https://d.sb/2019/07/wireguard-on-openvz-lxc
    sed -e 's/\(MaxSegmentSize *=\).*/\1 1700/' -e 's/\(PreallocatedBuffersPerPool =\).*/\1 1024/' -i device/queueconstants_default.go
    echo -e "${GREEN} -> Modifying Makefile...${GREY}"
    sed -e 's/\(go build -v\)/\1 -ldflags "-s -w"/' -i Makefile
    git update-index --assume-unchanged device/queueconstants_default.go
    echo -e -n "${NC}"
    if checkSHA256 main.go $MODIFIED_main && checkSHA256 device/queueconstants_default.go $MODIFIED_queueconstants_default && checkSHA256 Makefile $MODIFIED_makefile; then
      return 0
    fi
    return 1
  fi

  return 1
}

wg() {
  echo -e "${GREEN}:Processing wg-go${GREY}"

  cd ${REPO_ROOT_DIR}
  if [ ! -d wg-go ]; then
    git clone https://github.com/seud0nym/wg-go.git
  fi

  cd ${REPO_ROOT_DIR}/wg-go
  if [ -n "$(git diff)" ]; then
    echo -e "${RED}:ERROR: Uncommited changes in wg-go repository${NC}"
    return 1
  fi

  return 0
}

build_package() {
  local arch="$1"
  local version="$2"
  local ipk="wireguard-go_${version}_$arch.ipk"
  local size sha256 obsolete installed_size=$(cat $(find "$BASE_DIR/release/usr" "$BASE_DIR/release/lib" -type f ! -name .gitkeep) | wc -c)

  echo -e "${GREEN} -> Building $BASE_DIR/repository/$arch/base/${ipk}...${GREY}"
  mkdir -p $BASE_DIR/repository/$arch/base
  #region $BASE_DIR/release/control
  cat <<CTL > "$BASE_DIR/release/control"
Package: wireguard-go
Version: $version
Depends: libc
Source: N/A
License: MIT
LicenseFiles: LICENSE
Priority: optional
Section: net
Maintainer: seud0nym <seud0nym@yahoo.com.au>
Architecture: $arch
Installed-Size: $installed_size
Description: WireGuard is a novel VPN that utilizes state-of-the-art cryptography. It 
  aims to be faster, simpler, leaner, and more useful than IPSec, while 
  avoiding the massive headache. It intends to be considerably more 
  performant than OpenVPN.  WireGuard is designed as a general purpose VPN 
  for running on embedded interfaces and super computers alike, fit for 
  many different circumstances. It uses UDP.

  This package provides the official userspace implementation of WireGuard 
  plus \`wg-go\`, a userspace implementation of the control program \`wg(8)\`, 
  and the netifd protocol helper.
CTL
  #endregion
  $BASE_DIR/bin/make_ipk.sh "$BASE_DIR/repository/$arch/base/${ipk}" "$BASE_DIR/release"
  if [ $? -eq 0 ]; then
    cp -f "$BASE_DIR/repository/$arch/base/${ipk}" "$BASE_DIR/$(basename $BASE_DIR)_${arch}.ipk"
    size=$(cat "$BASE_DIR/repository/$arch/base/${ipk}" | wc -c)
    sha256=$(sha256sum "$BASE_DIR/repository/$arch/base/${ipk}" | cut -d" " -f1)
    sed -e "/^Installed-Size:/a\Filename: ${ipk}\nSize: ${size}\nSHA256sum: ${sha256}" "$BASE_DIR/release/control" > "$BASE_DIR/repository/$arch/base/Packages"
    ${BASE_DIR}/bin/usign -S -m "$BASE_DIR/repository/$arch/base/Packages" -s ${BASE_DIR}/keys/seud0nym-private.key -x "$BASE_DIR/repository/$arch/base/Packages.sig"
    gzip -fk "$BASE_DIR/repository/$arch/base/Packages"
    obsolete=$(ls $BASE_DIR/repository/$arch/base/*.ipk 2>/dev/null | grep -v $version)
    [ -n "$obsolete" ] && rm $obsolete
  else
    echo -e "${RED}: Failed to create package $BASE_DIR/repository/$arch/base/${ipk}!"
  fi
  echo -e -n "${NC}"
  rm $BASE_DIR/release/control $BASE_DIR/release/*.tar $BASE_DIR/release/*.tar.gz
}

build_release() {
  local tgz="$(basename $BASE_DIR)_$1.tgz" 

  local source
  local target
  local filename

  echo -e "${GREEN}:Creating $1 release asset $tgz...${GREY}"
  for source in "$REPO_ROOT_DIR/wireguard-go/wireguard-go" "$REPO_ROOT_DIR/wg-go/wg-go"; do
    cd "$(dirname "$source")"
    filename="$(basename $source)"
    echo -e "${GREEN} -> Building $1 $filename...${GREY}"
    make
    echo -e "${GREEN} -> Compressing $1 $filename...${GREY}"
    $BASE_DIR/bin/upx --ultra-brute $source
    target="$BASE_DIR/release/usr/bin/$filename"
    if ! cmp "$source" "$target" 2>/dev/null; then
      echo -e "${GREEN} -> Moving $source to $target...${GREY}"
      mv "$source" "$target"
    else
      echo -e "${ORANGE} -> Deleting $source (same as $target)...${GREY}"
      rm "$source"
    fi
  done

  echo -e "${GREEN} -> Building $BASE_DIR/$tgz...${GREY}"
  tar -zvcf $BASE_DIR/$tgz --mode=755 --exclude="*.git*" -C "$BASE_DIR/release" $(find "$BASE_DIR/release" -maxdepth 1 -type d ! -name . -printf "%P ")
  echo -e -n "${NC}"

  case "$1" in 
    armv5) build_package arm_cortex-a9 $VERSION;;
    arm64) build_package arm_cortex-a53 $VERSION;;
  esac
}

find . -maxdepth 1 -mindepth 1 -name 'openwrt-wireguard-go_*' -exec rm {} \;

if wg && wireguard; then
  echo -e "${GREY}"
  if ! cmp "$REPO_ROOT_DIR/wg-go/wg" "$BASE_DIR/release/usr/bin/wg" 1>&2 2>/dev/null; then
    echo -e "${GREEN}:Updating $BASE_DIR/release/usr/bin/wg...${GREY}"
    cp -p "$REPO_ROOT_DIR/wg-go/wg" "$BASE_DIR/release/usr/bin/wg"
    echo -e -n "${NC}"
  fi

  cd $BASE_DIR

  export GOOS="linux"
  for a in $@; do
    case "$a" in
      mipsel_24kc)
        # OpenWrt mipsel 24kc targets expect mipsle + softfloat
        export GOARCH="mipsle"
        export GOMIPS="softfloat"
        build_release "$a"
        unset GOMIPS
        ;;
      mipsel_24kc_hard|mipsel_24kc_hardfloat)
        # optional hardfloat variant
        export GOARCH="mipsle"
        export GOMIPS="hardfloat"
        build_release "$a"
        unset GOMIPS
        ;;
      arm)
        export GOARCH="arm"
        for v in $ARM; do
          export GOARM="$v"
          build_release "${a}v${v}"
          unset GOARM
        done
        ;;
      *)
        export GOARCH="$a"
        build_release "$a"
        ;;
    esac
    unset GOARCH
  done
  unset GOOS

  for f in wg wg-go wireguard-go; do
    [ -e "$BASE_DIR/release/usr/bin/$f" ] && rm "$BASE_DIR/release/usr/bin/$f"
  done
fi

echo -e "${GREEN}:Finished${NC}"
