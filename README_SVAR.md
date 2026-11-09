Oppgave 1A
Build og kjøre: 
docker build -t wishifai .
docker run -p 9999:8080 -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY wishifai
Krever da AWS-keys satt i terminal
Det blir multi-stage fordi vi har to FROM i Dockerfile ... Der den ene bygger hele greia, JAR-filen, maven og JDK, mens den andre bare bruker JAR-filen som resulterer i et image som tar mindre plass siden build tools ikke blir med. -p 9999:8080 kobler 9999 på maskinen til 8080 i containeren som gjør at localhost:9999 svarer.

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
Jeg brukte execution role og infrastructure role som står i oppgaven.
Jeg lagde Task role med suffiks for kandidatnummer, og ga den kun tillatelsene den trenger:
 - s3: skrive, lese og liste fra min bucket.
 - Rekognition: DetectLabels -> Be om labels fra et bilde.
 - Bedrock: InvokeModel -> sende prompt til model og InvokeModelWithResponseStream -> sende prompt til model og få respons i en stream.
 - CloudWatch: PutMetricData -> sender metrikken fra Micrometer.
Jeg lagde wishifai-10-images til bildene og har "force_destroy=true" så "terraform destroy" funker selv om det er bilder i bucketen.
S3_BUCKET: settes i terraform automatisk fra "aws_s3_bucket.images.bucket"
Jeg har variabler for region, candidate_number og image_tag som foreslås i oppgaven pluss ecr_repository og rollene som er ferdige.
Jeg har outputs for service_url, bucket_name, task_role_arn, service_arn og ingress_paths.

Oppgave 2B
Backend config ligger i "providers.tf" og pekker på pgr301-terraform-state som det står i oppgaven, og jeg bruker filnavn med mitt kandidat nummer -> key = "wishifai/10/terraform.tfstate" 

Oppgave 2C
Grønn kjøring:
 - https://github.com/kriss917/eksamen-2026-main/actions/runs/42222226874
Den feiler ved formateringsfeil siden jeg har "run: terraform fmt -check -recursive"
Rød kjøring grunnet formatering:
 - https://github.com/kriss917/eksamen-2026-main/actions/runs/42221680367
Ved endringer i tf filer kjør "terraform fmt -recursive" så er formateringen på plass.
Hvorfor terraform etter build:
Terraform refererer til et image med en bestemt tag i ECR, som ikke finnes før build har pushet imaget. Hvis terraform kjørte før eller samtidig kunne ECS prøvd å hente et image som ikke finnes enda, og deploy ville feilet eller startet med et gammelt image. needs: build_and_push gjør at den kun kjøres hvis buildet var vellykket.

Oppgave 3A
Metrikker sendes til CloudWatch med Micrometer, namespace "wishifai-10".
Rettet feil i MetricsConfig:
 - "namespace()" returnerte tom streng, så CloudWatch avviste alle metrikker ("The parameter Namespace is required"). Satt den til "wishifai-10".
Metrikker jeg la til:
 - wishifai.rekognition.duration (Timer): tid for Rekognition-kallet.
 - wishifai.bedrock.duration (Timer): tid for Bedrock-kallet.
 - wishifai.images.analyzed (Counter): antall analyserte bilder. Business-metrikk.
 - wishifai.gifts.suggested (Counter): antall gaveforslag generert. Business-metrikk.
 - wishifai.bedrock.parse.failures (Counter): antall ganger modellsvaret ikke kunne tolkes som JSON.
Hvorfor:
 - Rekognition og Bedrock er de to eksterne kallene, og da de mest sannsynlige årsakene til treg respons. Jeg måler bare selve AWS-kallet, slik at tallene viser hvor tiden går.
 - Business-metrikkene viser bruk (bilder) og levert verdi (forslag). Forslag per bilde sier også noe om kvaliteten på prompten.
 - parse.failures fanger en stille feil: "parseAnalysis" returnerer "(ukjent)" når modellen ikke svarer med gyldig JSON, og da reagerer ingen tekniske feilmetrikker.