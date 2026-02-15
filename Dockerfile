# Ubuntu based image which includes powershell (pwsh)
FROM mcr.microsoft.com/dotnet/sdk:8.0

# Install dependencies
ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y \
    curl \
    wget \
    unzip \
    git \
    bash \
    gnupg \
    software-properties-common \
    libglu1-mesa \
    build-essential \
    # lua5.1 \
    luarocks \
    ca-certificates \
    lsb-release \
    man \ 
    less \
    && rm -rf /var/lib/apt/lists/*

# Install neovim
RUN wget -qO- https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz | tar xzv
ENV PATH="$PATH:/nvim-linux-x86_64/bin"

# Install starship prompt and setup powershell prompt
RUN curl -sS https://starship.rs/install.sh | sh -s -- --yes
RUN mkdir -p ~/.config/powershell && echo 'Invoke-Expression (&starship init powershell)' > ~/.config/powershell/profile.ps1

# install nlua as lua interpreter
RUN luarocks --local install busted
RUN luarocks --local install nlua
RUN eval $(luarocks path --no-bin)
ENV PATH="$PATH:/root/.luarocks/bin"
ENV LUA_PATH="/test/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/root/.luarocks/share/lua/5.1/?.lua;/root/.luarocks/share/lua/5.1/?/init.lua"
ENV LUA_CPATH="/test/?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so;/root/.luarocks/lib/lua/5.1/?.so"

# Attach plugin directory to /test
WORKDIR /test

# Default shell
CMD pwsh
