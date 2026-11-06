Oppgave 1A
Build og kjøre: 
docker build -t wishifai .
docker run -p 9999:8080 -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY wishifai
Krever da AWS-keys satt i termianl
Det blir multi-stage fordi vi har to FROM i Dockerfile ... Der den ene bygger hele greia, JAR-filen, maven og JDK, mens den andre bare bruker JAR-filen som resulterer i et image som tar mindre plass siden build tools ikke blir med. -p 9999:8080 kobler 9999 på maskinen til 8080 i konteineren som gjør at localhost:9999 svarer.

Oppgave 1B
Grønn kjøring: 
 - https://github.com/kriss917/eksamen-2026-main/actions/runs/41628522441
Tagging strategi:
Imaget får to tagger -> full commit-SHA og latest
 - SHA gjør hvert image unikt og sporbart, så man vet nøyaktig hvilken kode som kjører og kan rulle tilbake til en bestemt versjon.
 - Latest er bare en praktisk peker til det siste bygget, og vil flytte seg for hvert bygg, så kan ikke brukes alene til å se hva som kjøres.

Oppgave 2A
All terraform kode ligger i infra/
Offentlig URL: https://wi-b503ad24c6c24e6a8ed8d06391673903.ecs.eu-west-1.on.aws
Test med:
curl https://wi-b503ad24c6c24e6a8ed8d06391673903.ecs.eu-west-1.on.aws/actuator/health
curl -F "image=@samples/sample_image.png" https://wi-b503ad24c6c24e6a8ed8d06391673903.ecs.eu-west-1.on.aws/api/analyze
Jeg brukte execution role og infrastructure role som alt finnes fordi du sier vi skal.
Jeg lagde Task role med suffiks for kandidatnummer, og ga den kun tillatelsene den trenger:
 -s3: skrive, lese og liste fra min bucket.
 -Reckognition: detectLabels -> Be om labels fra et bilde.
 - Bedrock: invokeModel -> sende promt til model og invokeModelWithResponseStream -> sende promt til model og få respons i en stream.
 - CloudWatch: cloudMetricData -> sender metrikken fra microMeter.
Jeg lagde wishifai-10-images til bildene og har "force_destroy=true" så "terraform destory" funker selv om det er bilder i bucketen.
S3_BUCKET: settes i terraform automatisk fra "aws_s3_bucket.images.bucket"

Oppgave 2B
Backend config ligger i "providers.tf" og pekker på pgr301-terraform-state som du sier i oppgaven, og jeg bruker filnavn med mitt kandidat nummer -> key = "wishifai/10/terraform.tfstate" 



 