Bash script to deploy Grafana, Prometheus and Node Exporter.

How to install:
1. In your VM, Container clone git repository:
   
   git clone https://github.com/almsys/init-grafana.git   
2. Run script to create 3 containers (Grafana, Prometeus and Node Exporter):

   sudo ./init-grafana/init_grafana.sh

3. Then open Grafana in your browser with login "admin" and password - "MyPassword1":

   YourMachineIPadrress:3000/


