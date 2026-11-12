### Kandidatnummer er 10

## Oppgave 1A

### Bygge og kjøre

```bash
docker build -t wishifai .

docker run -p 9999:8080 \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  wishifai
```
Krever da AWS-keys satt i terminal.
Region og bucket har default verdier i `application.properties` filen. Region:`eu-west-1` og bucket: `wishifai-uploads`.

### Hvorfor multi-stage

Dockerfilen har to `FROM`. Første stage bygger JAR-filen med Maven og JDK, mens andre stage kopierer bare JAR-en. Da følger ikke Maven, JDK eller kildekode med det endelige imaget, som gjør at det blir mindre.

### Portmapping

Appen lytter på 8080 inni containeren. Når vi skriver `-p 9999:8080` kobles port 9999 på maskinen til 8080 i containeren, som gjør at appen svarer på `localhost:9999`.

### Andre valg

`RUN useradd` oppretter en bruker inni imaget og `USER appuser` gjør at vi kjører som det i stedet for root-bruker.

### Test

```bash
curl http://localhost:9999/actuator/health
curl -F "image=@samples/sample_image.png" http://localhost:9999/api/analyze
```

## Oppgave 1B

### Workflow

Kjører kun på push til `main`.
AWS-nøkler ligger i Github secrets.

### Grønn kjøring
https://github.com/kriss917/eksamen-2026-main/actions/runs/41628522441

### Tagging strategi

Hvert image får to tagger:
- **Full commit-SHA**: gjør hvert image unikt og sporbart, så man vet nøyaktig hvilken kode som kjører og kan rulle tilbake til en bestemt versjon.
- **Latest**: er bare en praktisk peker til det siste bygget, og vil flytte seg for hvert bygg, så kan ikke brukes alene til å se hva som kjøres.

## Oppgave 2A

All terraform kode ligger i `infra/`.

**Offentlig URL**: https://wi-b503ad24c6c24e6a8ed8d06391673903.ecs.eu-west-1.on.aws

### Test

```bash
curl https://wi-b503ad24c6c24e6a8ed8d06391673903.ecs.eu-west-1.on.aws/actuator/health
curl -F "image=@samples/sample_image.png" https://wi-b503ad24c6c24e6a8ed8d06391673903.ecs.eu-west-1.on.aws/api/analyze
```

### Ressurser

- **ECS Express** som kjører imaget fra ECR. 
- **S3-bucket** `wishifai-10-images` for opplastede bilder. `force_destroy = true` er satt
  slik at `terraform destroy` fungerer selv med bilder i bucketen. Det er et bevisst valg for
  eksamen, og ville ikke vært riktig for en bucket med ekte brukerbilder i produksjon.
- **Task role** `wishifai-task-role-10` er opprettet i terraform.
- **Execution role og infrastructure role** er de eksisterende rollene fra oppgaven, referert
  via variabler og ikke opprettet på nytt.

### Task role-tillatelser 

- **s3**: `PutObject`, `GetObject`, `ListBucketskrive` -> skrive, lese og liste fra min bucket.
- **Rekognition**: `DetectLabels` -> Be om labels fra et bilde.
- **Bedrock**: `InvokeModel` -> sende prompt til model og `InvokeModelWithResponseStream` -> sende prompt til modellen og få respons i en stream.
- **CloudWatch**: `PutMetricData` -> sender metrikken fra Micrometer.

Bedrock og CloudWatch er ikke begrenset til bestemte ressurser, og kunne(burde) vært strammet in, men har prioritert at det faktisk funker.

### Variabler og outputs

- **Variabler:** `region`, `candidate_number`, `image_tag`, `ecr_repository`,
  `execution_role_arn`, `infrastructure_role_arn`. `image_tag` har ingen default med vilje og settes av CI.
- **S3_BUCKET:** settes automatisk fra `aws_s3_bucket.images.bucket`, og er ikke hardkodet.
- **Outputs:** `service_url`, `bucket_name`, `task_role_arn`, `service_arn`,
  `ingress_paths` og `dashboard_name` (Oppgave 3).

## Oppgave 2B

State lagres i S3-bucketen `pgr301-terraform-state` med nøkkelen
`wishifai/10/terraform.tfstate`. Nøkkelen inneholder mitt kandidatnummer,
så state er unikt.

## Oppgave 2C

Workflowen har begge jobbene i samme fil. `terraform` har `needs: build_and_push`, og kjører
`fmt -check`, `init`, `validate` og `apply` mot `infra/`. AWS-nøklene kommer fra GitHub Secrets.
SHA-taggen fra build-jobben sendes til Terraform som `image_tag`.

### Grønn kjøring
https://github.com/kriss917/eksamen-2026-main/actions/runs/42222226874

### Rød kjøring grunnet formatering
https://github.com/kriss917/eksamen-2026-main/actions/runs/42221680367

Den feiler ved formateringsfeil siden jeg har "run: terraform fmt -check -recursive".
Ved endringer i tf filer kjør "terraform fmt -recursive" så er formateringen på plass.

### Hvorfor terraform etter build

Terraform refererer til et image med en bestemt tag i ECR, som ikke finnes før build har pushet imaget. Hvis terraform kjørte før eller samtidig kunne ECS prøvd å hente et image som ikke finnes enda, og deploy ville feilet eller startet med et gammelt image. `needs: build_and_push` gjør at den kun kjøres hvis buildet var vellykket.

## Oppgave 3A

Metrikker sendes til CloudWatch med Micrometer under namespace `wishifai-10`.

### Rettet feil i MetricsConfig:

`namespace()` returnerte tom streng, så CloudWatch avviste alle metrikker ("The parameter Namespace is required"). Satt den til `wishifai-10`.
 
### Metrikker
- `wishifai.rekognition.duration` (Timer): tid for Rekognition-kallet.
- `wishifai.bedrock.duration` (Timer): tid for Bedrock-kallet.
- `wishifai.images.analyzed` (Counter): antall analyserte bilder. Business-metrikk.
- `wishifai.gifts.suggested` (Counter): antall gaveforslag generert. Business-metrikk.
- `wishifai.bedrock.parse.failures` (Counter): antall ganger modellsvaret ikke kunne tolkes som JSON.

### Hvorfor disse metrikkene

- **Timere rundt Rekognition og Bedrock:** De to eksterne kallene er de mest sannsynlige årsakene til treg respons. Jeg måler bare selve AWS-kallet, slik at tallene viser hvor tiden går.
- **Business-metrikker:** `images.analyzed` viser bruk, og `gifts.suggested` viser levert verdi. Forholdet mellom dem sier også noe om hvor mange forslag hver analyse gir.
- **`parse.failures`:** Den fanger en feil som ellers er usynlig. Når modellen ikke svarer med gyldig JSON,returnerer `parseAnalysis` fallback-verdien `(ukjent)`, og brukeren får et svar uten at HTTP-status eller feilrate ser noe galt.

### Kjent feil

En respons som ikke er JSON feiler inne i `parseAnalysis`. Kommer det en tom respons derimot feiler vi før, `.content().get(0)` gir en feil som ikke plukkes opp og gir bruker 500 og ingen feil registrert i Cloudwatch.
 
## Oppgave 3B

Dashboard: wishifai-10 (CloudWatch), er i infra/monitoring.tf. Screenshot ligger i media mappen -> media/dashboard.png.
Metrikker i dashboardet:
 - Business: "wishifai.images.analyzed.count" og "wishifai.gifts.suggested.count". Viser bruk og levert verdi.
 - Tid per kall: "wishifai.bedrock.duration.avg" og "wishifai.rekognition.duration.avg" side om side. Viser at Bedrock bruker rundt 15 sekunder mot rundt 0,7 sekunder for Rekognition, så den trege responsen skyldes språkmodellen.
 - Bedrock-parsing: wishifai.bedrock.parse.failures.count hvis alarmen går vil det dukke opp her, så kan jeg se om det er en feil eller flere som trigget alarmen.
 - Infrastruktur (ECS): CPUUtilization, MemoryUtilization og LiveTaskCount. Viser at flaskehalsen ikke er maskinressurser: CPU og minne er lavt mens responstiden er høy.
 - Applikasjon (Actuator): http.server.requests.avg/max for POST /api/analyze og jvm.memory.used.value for heap. HTTP-latensen bekrefter totaltiden brukeren ser, og JVM-heap viser at appen ikke har minneproblemer.
Alarm: wishifai-10-bedrock-parse-failures
 - Går når minst ett Bedrock-svar i løpet av 5 minutter ikke kunne tolkes som JSON
 - Hvorfor: da returnerer appen "(ukjent)" til brukeren mens HTTP-status, latens og feilrate ser friske ut. Ingen tekniske metrikker fanger det.
 - treat_missing_data = notBreaching, så perioder uten trafikk ikke gir falsk alarm.

## Oppgave 4

Generativ AI er ikke deterministisk. Alt teknisk kan fungere, og modellen kan gi gode resultater en stund før den plutselig gir et upassende svar. I Wishifai skal det litt til før det går galt, siden det bare er gaveforslag, men i mange andre applikasjoner kan det få store konsekvenser. Hvor strengt applikasjonen testes og overvåkes, avhenger derfor av hva en feil kan koste.

Testing. Vanlige tester forventer samme svar hver gang, og det får man ikke fra en LLM. Samme bilde kan gi ulike gaveforslag fra gang til gang. Det jeg likevel kan teste vanlig, er koden rundt: at labels fra Rekognition blir til en fornuftig prompt, og at "parseAnalysis" takler både gyldig JSON og søppel, med Bedrock mocket. For selve svarene ville jeg laget et eval-sett: en liten samling bilder jeg kjører gjennom tjenesten hver gang noe endres, og sjekker at svarene følger reglene våre. For eksempel gyldig JSON, ikke mer enn fem forslag, ingen generiske gaver som «en bok», og ikke alkohol til et barnerom. En annen LLM kan også vurdere om gavene passer, men et menneske må stikkprøvekontrollere resultatet. Eval-settet kan kjøre i pipelinen før deploy.

Kontinuerlig leveranse. Prompten ligger i "BedrockService", og modell-ID-en ligger i konfigurasjon. Det betyr at oppførselen kan endre seg uten at resten av koden gjør det. Derfor må prompt og modell behandles som kode: i git, gjennom pipelinen og med image tagget med commit-SHA, slik at jeg kan rulle tilbake hvis noe blir verre. For gaver er det greit å rulle ut rett. Når konsekvensene er større, bør man slippe ut til en liten andel brukere først (canary) eller bruke feature flag, og sammenligne kvaliteten før alle får den nye versjonen.

Overvåking. Dashboardet mitt viser at Bedrock bruker rundt 15 sekunder mens Rekognition bruker under ett sekund, så latens er et reelt problem. Alarmen min går på "bedrock.parse.failures", fordi den fanger en feil som ellers er usynlig: appen svarer 200, men brukeren får «(ukjent)». Den fanger ikke det verste, nemlig et svar som er gyldig JSON, men upassende, som en skarp kniv til et barnerom. Det er vanskeligere å oppdage uten for eksempel tilbakemeldinger fra brukere.

Risikonivå. Hos meg er det verste som kan skje at noen får en dårlig gaveidé, så det går greit å oppdage først i produksjon. Hadde det vært en bank eller medisinsk rådgivning, ville jeg ikke latt modellen svare uten at et menneske leser rådet først, og endringer i prompt eller modell måtte godkjennes av noen før de gikk ut i produksjon.