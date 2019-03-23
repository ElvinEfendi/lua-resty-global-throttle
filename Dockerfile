FROM openresty/openresty:stretch-fat

RUN apt-get update && apt-get -yq install cpanminus build-essential
RUN cpanm --notest Test::Nginx
