FROM itzg/minecraft-server:latest

RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | tee /etc/apt/sources.list.d/ngrok.list &&  \
    apt update &&  \
    apt install dnsutils ngrok -y

COPY --chmod=755 ./init-ncfs.sh /

ENTRYPOINT ["/bin/bash", "-c" , "/init-ncfs.sh && /start"]