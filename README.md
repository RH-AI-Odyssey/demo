# AI Odyssey 2025 demo-project
<div align="center">
<img src="./VirtualAIOdysseyLogo.png" width="150" height="150">
</div>
<br/>

<br/><b>[AI Odyssey Demo Project Architecture](https://docs.google.com/presentation/d/17G_gy3ShNI90dFPp-mYdifq7UIO6CpE_A9Ew5iFiISg/edit?usp=sharing)</b>

### Tested environment:
- AWS with OpenShift Open Environment from [Demo Platform](https://demo.redhat.com)
- Enable Cert Manager: yes
- Enable FIPS: no
- Configure Authentication: no
- Region: us-east-2
- OpenShift version: 4.18
- Control Plane Count: 1
- Control Plane Instance Type: m6a.4xlarge

### Steps to run the Demo Project:
To deploy demostration you must connect to bastion:
```
ssh lab-user@bastion.xxxxx.sandboxXXXX.opentlc.com
```
clone this repository
```
git clone https://github.com/RH-AI-Odyssey/demo.git
cd demo
```
Run the installer script
```
chmod +x install.sh
./install.sh
```
And wait for the magic...


### Additional config
This demo install by default Telegram (chatbot-rag) and Developer (devhub+devspaces) demos.
you need to configurate a enviroment variables to select wich demo activate.

if you want to enable only telegram demo:
```
export INSTALL_TELEGRAM_DEMO=true
export INSTALL_DEV_DEMO=false
``` 

if you want to enable only developer demo:
```
export INSTALL_TELEGRAM_DEMO=false
export INSTALL_DEV_DEMO=true
``` 
