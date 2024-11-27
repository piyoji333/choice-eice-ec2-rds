# choice-eice-ec2-rds

前提
各リソース名には"prd" or "stg"　が入っている必要があります(EC2,RDS,Endpoint)

デフォルトパス(~/.aws/)にAWSクレデンシャルファイルを配置してあること

クレデンシャルファイルは以下のように記載


[project1]
aws_access_key_id = aaaaaaaaaaaaa
aws_secret_access_key = aaaaaaaaaaaaaa
[project2]
aws_access_key_id = bbbbbbbb
aws_secret_access_key = bbbbbbbbbb


usage:

./choice-eice-ec2-rds.sh


実行時にクレデンシャルファイルに記載されているprojectnameを指定できます
（指定しなくても実行時に選択可能）
