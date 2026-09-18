FROM mcr.microsoft.com/devcontainers/javascript-node:22-bookworm

ARG ROKIT_VERSION=1.2.0
ARG LUAUDOCS_VERSION=0.2.0

USER root
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl unzip \
	&& rm -rf /var/lib/apt/lists/* \
	&& npm install --global "luaudocs@${LUAUDOCS_VERSION}"

USER node
# Install upstream Rokit directly; project tool versions stay in rokit.toml.
RUN mkdir -p /home/node/.rokit/bin \
	&& curl -fsSL --retry 3 \
		"https://github.com/rojo-rbx/rokit/releases/download/v${ROKIT_VERSION}/rokit-${ROKIT_VERSION}-linux-$(uname -m).zip" \
		-o /tmp/rokit.zip \
	&& unzip -q /tmp/rokit.zip rokit -d /home/node/.rokit/bin \
	&& chmod +x /home/node/.rokit/bin/rokit \
	&& rm /tmp/rokit.zip

# Available to terminals, tasks, and language servers in every container client.
ENV PATH="/home/node/.rokit/bin:${PATH}"
