#!/bin/bash

# --- CONFIGURAÇÕES DE CORES ---
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
AZUL='\033[0;34m'
NC='\033[0m' # Sem cor

echo -e "${AZUL}========================================${NC}"
echo -e "${AZUL}   Ferramenta de Diagnóstico de Hardware  ${NC}"
echo -e "${AZUL}========================================${NC}"

# --- CHECK: USUÁRIO ROOT ---
# O acesso direto ao hardware exige privilégios de superusuário.
if [ "$EUID" -ne 0 ]; then
  echo -e "${VERMELHO}Por favor, execute como root (sudo) para ler os sensores físicos.${NC}"
  exit
fi

# --- DEPENDÊNCIAS ---
# Verifica se as ferramentas de disco estão instaladas (foco em ambientes Fedora/Red Hat)
if ! command -v smartctl &> /dev/null || ! command -v hdparm &> /dev/null; then
    echo -e "${AMARELO}Instalando ferramentas de diagnóstico (smartmontools e hdparm)...${NC}"
    dnf install -y smartmontools hdparm > /dev/null 2>&1
fi

# --- MÓDULO 1: IDENTIFICAÇÃO DO SISTEMA ---
echo -e "\n${VERDE}[1/4] Resumo do Sistema${NC}"

# Extrai o modelo exato do processador
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name: *//')
echo -e "Processador: ${AMARELO}$CPU_MODEL${NC}"

# Verifica a quantidade total de RAM
RAM_TOTAL=$(free -h | grep Mem | awk '{print $2}')
echo -e "Memória RAM Total: ${AMARELO}$RAM_TOTAL${NC}"

# --- MÓDULO 2: TESTE DE MEMÓRIA (RÁPIDO) ---
echo -e "\n${VERDE}[2/4] Consumo Atual de Memória RAM${NC}"
free -m | awk 'NR==2{printf "Uso Atual: %sMB / Total: %sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'

# --- MÓDULO 3: IDENTIFICAÇÃO DA UNIDADE DE ARMAZENAMENTO ---
# Identifica automaticamente o disco principal (geralmente sda ou nvme0n1)
DISCO=$(lsblk -d -o NAME,TYPE | grep disk | awk 'NR==1{print $1}')

echo -e "\n${VERDE}[3/4] Teste de Velocidade de Leitura (SSD/HDD - /dev/$DISCO)${NC}"
if [ -n "$DISCO" ]; then
    # O hdparm faz um teste de leitura do cache e do disco físico
    hdparm -tT /dev/$DISCO | grep -E "Timing"
else
    echo -e "${VERMELHO}Nenhum disco compatível encontrado.${NC}"
fi

# --- MÓDULO 4: SAÚDE DO DISCO (S.M.A.R.T.) ---
echo -e "\n${VERDE}[4/4] Status de Saúde do Armazenamento (S.M.A.R.T.)${NC}"
if [ -n "$DISCO" ]; then
    # Lê o log interno do controlador do disco
    SAUDE=$(smartctl -H /dev/$DISCO | grep "test result" | cut -d ':' -f 2 | xargs)

    if [ "$SAUDE" == "PASSED" ]; then
        echo -e "Avaliação do Controlador: ${VERDE}APROVADO (Saudável)${NC}"
    else
        echo -e "Avaliação do Controlador: ${VERMELHO}FALHA DETECTADA (Possível risco de perda de dados)${NC}"
    fi
fi
# --- MÓDULO 5: TEMPERATURA DA CPU ---
echo -e "\n${VERDE}[5/5] Monitoramento Térmico (CPU)${NC}"

# Instala o lm_sensors se não estiver presente
if ! command -v sensors &> /dev/null; then
    echo -e "${AMARELO}Instalando pacote lm_sensors...${NC}"
    dnf install -y lm_sensors > /dev/null 2>&1
fi

# Busca a temperatura capturando os padrões mais comuns (AMD Tctl ou Intel Core/Package)
TEMP_CPU=$(sensors 2>/dev/null | grep -iE 'tctl|package id 0|core 0' | head -n 1 | awk '{print $2}')

if [ -n "$TEMP_CPU" ]; then
    echo -e "Temperatura Atual: ${AMARELO}$TEMP_CPU${NC}"
    echo -e "${AZUL}(Dica de Bancada: Temperaturas em repouso acima de 55°C-60°C indicam necessidade de troca de pasta térmica.)${NC}"
else
    echo -e "${VERMELHO}Sensor térmico não detectado de imediato. Pode ser necessário rodar 'sensors-detect'.${NC}"
fi

echo -e "\n${AZUL}========================================${NC}"
echo -e "${VERDE}Diagnóstico concluído!${NC}"
