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

 