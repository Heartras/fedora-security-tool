#!/bin/bash

# --- FUNÇÃO DE BACKUP ---
# Cria uma cópia de segurança antes de qualquer alteração.
fazer_backup() {
    local ARQUIVO=$1
    if [ -f "$ARQUIVO" ]; then
        cp "$ARQUIVO" "${ARQUIVO}.bak_$(date +%F_%H%M)"
        echo -e "${VERDE}Backup de $ARQUIVO criado com sucesso.${NC}"
    fi
}

# Registra toda a atividade do script para auditoria posterior.
DATA_ATUAL=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="fedora_setup_${DATA_ATUAL}.log"

# Redireciona a saída padrão (stdout) e de erro (stderr) para o terminal E para o log
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo -e "${VERDE}Logs desta sessão serão salvos em: $LOG_FILE${NC}"

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m' # Sem cor

echo -e "${VERDE}Iniciando o Fedora 43 Power-Up Script...${NC}"

# --- CHECK: USUÁRIO ROOT ---
# Essencial para disciplinas de SO: verificar privilégios de processo.
if [ "$EUID" -ne 0 ]; then 
  echo -e "${VERMELHO}Por favor, execute como root (sudo).${NC}"
  exit
fi

# --- MÓDULO 1: OTIMIZAÇÃO DO DNF ---
# Melhora a performance de download de pacotes no Fedora.
echo -e "\n[1/2] Otimizando o DNF..."
DNF_CONF="/etc/dnf/dnf.conf"

if ! grep -q "max_parallel_downloads" "$DNF_CONF"; then
    echo "max_parallel_downloads=10" >> "$DNF_CONF"
    echo "fastestmirror=True" >> "$DNF_CONF"
    echo -e "${VERDE}Configurações de velocidade aplicadas!${NC}"
else
    echo "DNF já parece estar otimizado."
fi

# --- MÓDULO 2: BASE DE HARDENING (SEGURANÇA) ---
# Foco em cibersegurança e defesa de redes.
echo -e "\n[2/2] Verificando Hardening Inicial..."

# Verificando o SELinux (Conceito de SO 1 e Segurança)
STATUS_SELINUX=$(sestatus | awk '{print $3}')
echo "Status do SELinux: $STATUS_SELINUX"

# Garantindo que o Firewall esteja ativo
systemctl enable --now firewalld > /dev/null 2>&1
echo -e "${VERDE}Firewall (firewalld) ativado e em execução.${NC}"

echo -e "\n${VERDE}Script concluído com sucesso!${NC}"

# --- MÓDULO 3: VIRTUALIZAÇÃO (KVM/QEMU/VIRT-MANAGER) ---
# Essencial para o laboratório de Whonix e estudos de Redes.
echo -e "\n[3/3] Configurando ambiente de Virtualização..."

# Instalação dos pacotes necessários para o Fedora
dnf install -y virt-manager libvirt qemu-kvm qemu-img virt-viewer libvirt-client libvirt-daemon-config-network libvirt-daemon-kvm

# Iniciando e habilitando o serviço da libvirt
systemctl enable --now libvirtd

# Adicionando seu usuário ao grupo libvirt (para rodar sem pedir senha toda hora)
# Substitua 'arthur' pelo seu usuário real se necessário, ou use a variável $SUDO_USER
usermod -aG libvirt $SUDO_USER

echo -e "${VERDE}Ambiente de virtualização pronto! (Reinicie a sessão para aplicar os grupos)${NC}"

# --- DICA DE SEGURANÇA (HARDENING) ---
# Desativando interfaces de rede virtuais padrão se não estiverem em uso
virsh net-autostart default --disable > /dev/null 2>&1
echo -e "${VERDE}Configuração de rede virtual padrão otimizada.${NC}"

# --- MÓDULO 4: AUDITORIA DE REDE (PORTAS E SERVIÇOS) ---
# Foco em identificar possíveis brechas e serviços rodando no Fedora 43.
echo -e "\n[4/4] Realizando Auditoria de Portas Abertas..."

# O comando ss -tulpn:
# -t (TCP), -u (UDP), -l (Listening), -p (Process), -n (Numeric)
echo -e "${VERDE}Listando serviços em escuta (LISTEN):${NC}"
ss -tulpn | grep "LISTEN" | column -t

echo -e "\n${VERDE}Dica de Segurança:${NC} Se encontrar portas como 22 (SSH) ou 80 (HTTP) abertas sem necessidade, considere desativar o serviço."
