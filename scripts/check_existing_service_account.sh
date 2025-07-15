#!/bin/bash
# scripts/check_service_accounts_fixed.sh
# Verificar Service Accounts existentes y sus permisos

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ID="as-database-337918"

echo -e "${BLUE}🔍 Análisis de Service Accounts Existentes (CORREGIDO)${NC}"
echo "==========================================================================="
echo ""

# Listar todas las Service Accounts del proyecto
echo -e "${YELLOW}📋 1. Listando todas las Service Accounts:${NC}"
echo ""

# Obtener lista de SAs en formato procesable
SA_EMAILS=$(gcloud iam service-accounts list --project=$PROJECT_ID --format="value(email)")

if [ -z "$SA_EMAILS" ]; then
    echo -e "${RED}❌ No se encontraron Service Accounts en el proyecto${NC}"
    exit 1
fi

# Contar SAs
SA_COUNT=$(echo "$SA_EMAILS" | wc -l)
echo -e "${GREEN}✅ Encontradas $SA_COUNT Service Accounts${NC}"
echo ""

# Listar SAs con sus nombres
echo "$SA_EMAILS" | while read -r email; do
    if [ -n "$email" ]; then
        display_name=$(gcloud iam service-accounts describe "$email" --project=$PROJECT_ID --format="value(displayName)" 2>/dev/null || echo "Sin nombre")
        echo "   📧 $email"
        echo "      └─ Nombre: $display_name"
    fi
done
echo ""

# Analizar cada Service Account individualmente
echo -e "${YELLOW}🎯 2. Analizando roles IAM de cada Service Account:${NC}"
echo ""

COUNTER=1
RECOMMENDED_SAS=()

echo "$SA_EMAILS" | while read -r email; do
    if [ -n "$email" ]; then
        echo -e "${BLUE}[$COUNTER/$SA_COUNT] 🤖 $email${NC}"
        
        # Obtener display name
        display_name=$(gcloud iam service-accounts describe "$email" --project=$PROJECT_ID --format="value(displayName)" 2>/dev/null || echo "Sin nombre")
        echo "   📝 Nombre: $display_name"
        
        # Obtener roles ESPECÍFICOS de esta SA
        echo "   🔍 Obteniendo roles IAM..."
        SA_ROLES=$(gcloud projects get-iam-policy $PROJECT_ID \
            --flatten="bindings[].members" \
            --format="value(bindings.role)" \
            --filter="bindings.members:serviceAccount:$email" 2>/dev/null | sort | uniq)
        
        if [ -n "$SA_ROLES" ]; then
            echo -e "   ${GREEN}✅ Roles asignados:${NC}"
            
            # Mostrar cada rol
            while IFS= read -r role; do
                if [ -n "$role" ]; then
                    echo "      • $role"
                    
                    # Evaluar roles importantes
                    case $role in
                        "roles/owner")
                            echo -e "        ${GREEN}🏆 EXCELENTE: Owner tiene TODOS los permisos${NC}"
                            ;;
                        "roles/editor")
                            echo -e "        ${GREEN}⭐ MUY BUENO: Editor tiene permisos amplios${NC}"
                            ;;
                        "roles/cloudfunctions.admin")
                            echo -e "        ${GREEN}✅ Perfecto para Cloud Functions${NC}"
                            ;;
                        "roles/cloudbuild.builds.builder")
                            echo -e "        ${GREEN}✅ Perfecto para Cloud Build${NC}"
                            ;;
                        "roles/iam.serviceAccountUser")
                            echo -e "        ${GREEN}✅ Puede usar Service Accounts${NC}"
                            ;;
                        "roles/compute.instanceAdmin.v1"|"roles/compute.admin")
                            echo -e "        ${YELLOW}ℹ️  Permisos de Compute Engine${NC}"
                            ;;
                    esac
                fi
            done <<< "$SA_ROLES"
            
            echo ""
            echo -e "   ${YELLOW}📊 Evaluación para CI/CD:${NC}"
            
            # Evaluación específica para CI/CD
            HAS_OWNER=$(echo "$SA_ROLES" | grep -c "roles/owner" || true)
            HAS_EDITOR=$(echo "$SA_ROLES" | grep -c "roles/editor" || true)
            HAS_CF_ADMIN=$(echo "$SA_ROLES" | grep -c "roles/cloudfunctions.admin" || true)
            HAS_CB_BUILDER=$(echo "$SA_ROLES" | grep -c "roles/cloudbuild.builds.builder" || true)
            HAS_SA_USER=$(echo "$SA_ROLES" | grep -c "roles/iam.serviceAccountUser" || true)
            
            # Clasificar la SA
            if [ "$HAS_OWNER" -gt 0 ]; then
                echo -e "      🏆 ${GREEN}PERFECTA: Owner - puede hacer TODO${NC}"
                echo "         → Recomendación: USAR ESTA SA"
                RECOMMENDATION="PERFECTA"
            elif [ "$HAS_EDITOR" -gt 0 ]; then
                echo -e "      ⭐ ${GREEN}EXCELENTE: Editor - muy buenos permisos${NC}"
                echo "         → Recomendación: USAR ESTA SA"
                RECOMMENDATION="EXCELENTE"
            elif [ "$HAS_CF_ADMIN" -gt 0 ] && [ "$HAS_CB_BUILDER" -gt 0 ]; then
                echo -e "      ✅ ${GREEN}BUENA: Tiene roles específicos clave${NC}"
                echo "         → Recomendación: USAR ESTA SA"
                RECOMMENDATION="BUENA"
            else
                echo -e "      ⚠️  ${YELLOW}LIMITADA: Pocos permisos para CI/CD${NC}"
                echo "         → Recomendación: Buscar otra SA"
                RECOMMENDATION="LIMITADA"
            fi
            
            # Guardar recomendaciones para el resumen
            if [ "$RECOMMENDATION" = "PERFECTA" ] || [ "$RECOMMENDATION" = "EXCELENTE" ] || [ "$RECOMMENDATION" = "BUENA" ]; then
                # Esto no funciona bien en subshells, lo moveremos fuera del while
                echo "$email|$RECOMMENDATION|$display_name" >> /tmp/recommended_sas.txt
            fi
            
        else
            echo -e "   ${RED}❌ Sin roles asignados${NC}"
            echo -e "      → No puede usarse para CI/CD"
        fi
        
        echo ""
        echo "─────────────────────────────────────────────────────────────────────"
        echo ""
        
        COUNTER=$((COUNTER + 1))
    fi
done

# Resumen final
echo -e "${BLUE}📋 RESUMEN Y RECOMENDACIONES${NC}"
echo "==========================================================================="
echo ""

if [ -f "/tmp/recommended_sas.txt" ]; then
    echo -e "${GREEN}🎯 Service Accounts RECOMENDADAS para CI/CD:${NC}"
    echo ""
    
    while IFS='|' read -r email recommendation display_name; do
        case $recommendation in
            "PERFECTA")
                echo -e "   🏆 ${GREEN}PERFECTA${NC}: $email"
                ;;
            "EXCELENTE") 
                echo -e "   ⭐ ${GREEN}EXCELENTE${NC}: $email"
                ;;
            "BUENA")
                echo -e "   ✅ ${GREEN}BUENA${NC}: $email"
                ;;
        esac
        echo "      └─ $display_name"
        echo ""
    done < /tmp/recommended_sas.txt
    
    # Obtener la mejor recomendación
    BEST_SA=$(head -1 /tmp/recommended_sas.txt | cut -d'|' -f1)
    
    echo -e "${BLUE}🚀 SIGUIENTE PASO RECOMENDADO:${NC}"
    echo ""
    echo "Usar la Service Account más recomendada:"
    echo ""
    echo -e "${GREEN}./scripts/use_existing_service_account.sh --service-account $BEST_SA${NC}"
    echo ""
    
    # Limpiar archivo temporal
    rm -f /tmp/recommended_sas.txt
    
else
    echo -e "${YELLOW}⚠️  No se encontraron Service Accounts ideales para CI/CD${NC}"
    echo ""
    echo "Opciones:"
    echo "1. Usar la Service Account con más permisos disponible"
    echo "2. Solicitar al administrador que asigne permisos adicionales"
    echo "3. Crear una nueva SA con permisos específicos"
fi

echo ""
echo -e "${BLUE}💡 Para usar cualquier SA específica:${NC}"
echo "   ./scripts/use_existing_service_account.sh --service-account EMAIL"
echo ""
echo -e "${BLUE}🔍 Para ver este análisis de nuevo:${NC}"
echo "   ./scripts/check_service_accounts_fixed.sh"
echo ""
echo -e "${GREEN}✅ Análisis completado${NC}"