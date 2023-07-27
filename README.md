# Docker NCFS Minecraft Server

This Docker image combines the standard image of [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) with the addition of NCFS (Ngrok Cloudflare Forward Script) from [barbarbar338](https://github.com/barbarbar338/ncfs). The NCFS script allows you to tunnel your Minecraft server through ngrok and set a CNAME on top of the ngrok-URL using Cloudflare. This enables you to publish your Minecraft server without the need for port forwarding.

## Story

The motivation behind this project came from facing CGNAT (Carrier-Grade Network Address Translation) due to a new contract with my ISP. As a result, I couldn't create port forwards for my home services. I discovered Cloudflare Tunnel, which allowed me to tunnel HTTP(S) services, but I needed a solution for tunneling other protocols, like TCP, for my Minecraft server. After some research, I found NCFS on GitHub, which enabled me to tunnel TCP services (Minecraft Server) and create an alias (CNAME) for the public URL with my domain.

## Tutorial

### ngrok

You just need to obtain your authentication token from ngrok's [dashboard](https://dashboard.ngrok.com/get-started/your-authtoken).

That's it! If you don't have a domain from Cloudflare, you can jump to [Docker](#docker).
Please be aware that the URL given by ngrok will change at every server reboot.

### Cloudflare

If you have a paid domain at Cloudflare, you can make the temporary URL permanent by creating a CNAME record on ngrok's URL. Here's how to do it:

1. Get your `Global API Key` from Cloudflare's Dashboard, which can be found [here](https://dash.cloudflare.com/profile/api-tokens). 
   This key will be needed for the Docker container.
   ![Pasted image 20230727204547.png]

2. Select your desired domain under "Websites" in the [Cloudflare Dashboard](https://dash.cloudflare.com) and scroll down on the "Overview" page to find your `Zone ID`.
   ![Pasted image 20230727205033.png]

3. Navigate to "DNS Records" in the same Dashboard section as "Overview."

4. Create a new `CNAME record`. The name should be a part of your domain (e.g., name = minecraft => minecraft.yourdomain.tld). The highlighted URL in the screenshot below will be needed for Docker.
   ![Pasted image 20230727205447.png]

5. Initially, the target could be set to example.com. The target will be automatically updated by NCFS later.

6. Additionally, create an `SRV record`. The name could be something like "playmc" (e.g., name = `playmc` => playmc.yourdomain.tld). Only the highlighted part of the URL in the screenshot below is needed for Docker and will be used for connecting to the server later.

7. The service must be named `_minecraft`, and the protocol should be TCP (default selection).

8. Priority, weight, and port can be set to random numbers within the range shown below the inputs. These fields will be updated automatically when the server starts with NCFS.

9. The target should be set to your entire `CNAME domain`.
   ![Pasted image 20230727210104.png]

That's it! You can now continue with the Docker configuration.

### Docker

Now, you can create a `docker-compose.yml` file and copy the following configuration for a basic server without any whitelisting in the latest Minecraft version. If you want to configure your server a little bit more, you can just add the needed `environment` variables and control the server as mentioned [here](https://docker-minecraft-server.readthedocs.io/en/latest/):

```yaml
version: "3.8"  
services:  
  minecraft-server:  
    image: florianbreuker/minecraft-server  
    container_name: minecraft-server  
    tty: true  
    stdin_open: true  
    environment:  
      - EULA=TRUE  
      - NGROK_TCP_PORT=25565 # Minecraft server port, default is 25565  
      - NGROK_AUTH_TOKEN=<YOUR_NGROK_AUTH_TOKEN> # ngrok auth token  
      #  ONLY if you have a Cloudflare Domain      
      - CLOUDFLARE_AUTH_EMAIL=<YOUR_CLOUDFLARE_AUTH_EMAIL> # Cloudflare auth email  
      - CLOUDFLARE_API_KEY=<YOUR_CLOUDFLARE_API_KEY> # Cloudflare Global API Key  
      - CLOUDFLARE_ZONE_ID=<YOUR_CLOUDFLARE_ZONE_ID> # Cloudflare Zone ID  
      - CLOUDFLARE_CNAME_RECORD=<YOUR_CLOUDFLARE_CNAME_RECORD> # Cloudflare CNAME Domain        
      - CLOUDFLARE_SRV_RECORD=<YOUR_CLOUDFLARE_SRV_RECORD> # Cloudflare SRV Domain (for your connection)      
    volumes:  
      - ./configs/minecraft-server-config/data:/data
  ```
If you are using Cloudflare, you can connect to the server using the value from `CLOUDFLARE_SRV_RECORD_NAME`.

### Minecraft

Now, you can start the Minecraft version of your server in your Launcher. And connect to your server via the URLs.

![[Pasted image 20230727211658.png]]
