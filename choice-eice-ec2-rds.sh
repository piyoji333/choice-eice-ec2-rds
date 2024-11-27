#!/bin/bash

##-----------------
## 第1引数にAWScliのprofileを指定
##-----------------
PROFILE=$1

if [ -z $PROFILE ]; then
    echo "aws cli プロファイル名を数字から選択してください"
    PROFILES=$(aws configure list-profiles)
    select PROFILE in $PROFILES
    do
        echo "${PROFILE}が選択されました。"
        PROFILE=${PROFILE}
        break
    done
fi


echo "対象環境を数字から選択してください"
select ENV in "prd" "stg"
do
    echo "${ENV}が選択されました。"
    ENV=${ENV}
    break
done


##-----------------
## EICE選択
##-----------------
echo "EC2 Instance Connect Endpointを数字から選択してください"
TARGET_EICE_NAMES=$(aws ec2 describe-instance-connect-endpoints \
    --query 'InstanceConnectEndpoints[]' \
    --profile $PROFILE \
    --output text | grep $ENV | awk '{print $3}')

if [[ -z "$TARGET_EICE_NAMES" ]]; then
    echo "選択した環境にEC2 Instance Connect Endpointは存在しません。"
    exit 1
fi

select TARGET_EICE_NAME in $TARGET_EICE_NAMES
do
    echo "${TARGET_EICE_NAME}が選択されました。"
    TARGET_EICE_NAME=${TARGET_EICE_NAME}
    break
done

TARGET_EICE_ID=$(aws ec2 describe-instance-connect-endpoints \
    --query 'InstanceConnectEndpoints[].InstanceConnectEndpointId' \
    --filters Name=tag:Name,Values=$TARGET_EICE_NAME \
    --profile $PROFILE \
    --output text)

##EC2 or RDS

echo "接続する先を数字から選択してください"
select SERVICE in "EC2" "RDS"
do
    echo "${SERVICE}が選択されました。"
    SERVICE=${SERVICE}
    break
done

if [[ "$SERVICE" == EC2 ]]; then
    echo "EC2を数字から選択してください"
    TARGET_EC2_NAMES=$(aws ec2 describe-instances  \
    --query 'Reservations[].Instances[].Tags[?Key==`Name`].Value' \
    --profile $PROFILE \
    --output text | grep $ENV )
	if [[ -z "$TARGET_EC2_NAMES" ]]; then
    		echo "選択した環境にEC2は存在しません。"
    		exit 1
	fi
select TARGET_EC2_NAME in $TARGET_EC2_NAMES
do
    echo "${TARGET_EC2_NAME}が選択されました。"
    TARGET_EC2_NAME=${TARGET_EC2_NAME}
    break
done
TARGET_EC2_ID=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[].InstanceId' \
    --filters Name=tag:Name,Values=$TARGET_EC2_NAME \
    --profile $PROFILE \
    --output text)


##-----------------
## EC2接続先ポート
##-----------------
#echo "接続先ポートを入力してください:"
echo "port22へ接続します"
TARGET_PORT=22

##-----------------
## localポート
##-----------------
echo "localポートを入力してください:"
select LOCAL_PORT_OPTION in "入力" "選択"
do
    case ${LOCAL_PORT_OPTION} in
        "入力")
            read -p "localポートを入力してください: " LOCAL_PORT
            while true
            do
                if [[ ${LOCAL_PORT} =~ ^[0-9]+$ ]]; then
                    echo "${LOCAL_PORT}が選択されました。"
                    break
                else
                    echo "無効な入力です。ポート番号を入力してください。"
                    read -p "localポートを入力してください: " LOCAL_PORT
                fi
            done
            break
            ;;
        "選択")
            select PORT_SELECT in "10022" "12322" "11022"
            do
                echo "${PORT_SELECT}が選択されました。"
                LOCAL_PORT=${PORT_SELECT}
                break
            done
            break
            ;;
        *)
            echo "無効な選択です。もう一度選択してください。"
            ;;
    esac
done


##-----------------
## EC2接続
##-----------------
echo "EC2に接続します。"
aws ec2-instance-connect open-tunnel \
    --instance-connect-endpoint-id $TARGET_EICE_ID \
    --instance-id $TARGET_EC2_ID \
    --local-port  $LOCAL_PORT \
    --remote-port $TARGET_PORT \
    --profile $PROFILE


    exit 1
fi


##-----------------
## ReaderWriter選択
##-----------------
echo "接続するエンドポイントの種類を数字から選択してください"
select RDS_ENDPOINT in "Writer" "Reader"
do
    if [ "${ENV}" = "prod" ] && [ "${RDS_ENDPOINT}" = "Writer" ]; then
        echo "Writerはprodでは選択できません。"
    else
        echo "${RDS_ENDPOINT}が選択されました。"
        if [ "${RDS_ENDPOINT}" = "Writer" ]; then
            RDS_ENDPOINT="Endpoint"
        else
            RDS_ENDPOINT="ReaderEndpoint"
        fi
        break
    fi
done

##-----------------
## 接続先RDSエンドポイント選択
##-----------------
echo "接続するDatabaseを数字から選択してください"
TARGET_HOSTS=$(aws rds describe-db-clusters \
            --profile $PROFILE \
            --query 'DBClusters[?contains(Endpoint, `'$ENV'`)].['$RDS_ENDPOINT']' \
            --output text)
select TARGET_HOST in $TARGET_HOSTS
do
    echo "${TARGET_HOST}が選択されました。"
    TARGET_HOST=${TARGET_HOST}
    break
done

TARGET_HOST_IP=$(dig $TARGET_HOST +short | grep '^[0-9]')

##-----------------
## 接続先ポート
##-----------------
echo "接続先ポートを入力してください:"
select TARGET_PORT_OPTION in "入力" "選択"
do
    case ${TARGET_PORT_OPTION} in
        "入力")
            read -p "接続先ポートを入力してください: " TARGET_PORT
            while true
            do
                if [[ ${TARGET_PORT} =~ ^[0-9]+$ ]]; then
                    echo "${TARGET_PORT}が選択されました。"
                    break
                else
                    echo "無効な入力です。ポート番号を入力してください。"
                    read -p "接続先ポートを入力してください: " TARGET_PORT
                fi
            done
            break
            ;;
        "選択")
            select PORT_SELECT in "5432" "3306" "3389"
            do
                echo "${PORT_SELECT}が選択されました。"
                TARGET_PORT=${PORT_SELECT}
                break
            done
            break
            ;;
        *)
            echo "無効な選択です。もう一度選択してください。"
            ;;
    esac
done

##-----------------
## localポート
##-----------------
echo "localポートを入力してください:"
select LOCAL_PORT_OPTION in "入力" "選択"
do
    case ${LOCAL_PORT_OPTION} in
        "入力")
            read -p "localポートを入力してください: " LOCAL_PORT
            while true
            do
                if [[ ${LOCAL_PORT} =~ ^[0-9]+$ ]]; then
                    echo "${LOCAL_PORT}が選択されました。"
                    break
                else
                    echo "無効な入力です。ポート番号を入力してください。"
                    read -p "localポートを入力してください: " LOCAL_PORT
                fi
            done
            break
            ;;
        "選択")
            select PORT_SELECT in "15432" "13306" "13389"
            do
                echo "${PORT_SELECT}が選択されました。"
                LOCAL_PORT=${PORT_SELECT}
                break
            done
            break
            ;;
        *)
            echo "無効な選択です。もう一度選択してください。"
            ;;
    esac
done

##-----------------
## RDS接続
##-----------------
echo "RDSに接続します。"
aws ec2-instance-connect open-tunnel \
    --instance-connect-endpoint-id $TARGET_EICE_ID \
    --private-ip-address $TARGET_HOST_IP \
    --local-port  $LOCAL_PORT \
    --remote-port $TARGET_PORT \
    --profile $PROFILE

