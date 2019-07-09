FROM openresty/openresty:stretch-fat

RUN apt-get update && \
  apt-get -yq install cpanminus build-essential libreadline-dev unzip && \
  curl -sSL https://luarocks.org/releases/luarocks-3.1.3.tar.gz -o luarocks-3.1.3.tar.gz && \
    tar zxpf luarocks-3.1.3.tar.gz && \
    cd luarocks-3.1.3 && \
    ./configure --prefix=/usr/local/openresty/luajit \
      --with-lua=/usr/local/openresty/luajit/ \
      --lua-suffix=jit \
      --with-lua-include=/usr/local/openresty/luajit/include/luajit-2.1 && \
    make build && \
    make install

RUN cpanm --notest Test::Nginx
RUN luarocks install busted
