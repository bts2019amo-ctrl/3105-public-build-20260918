# Build do 3105

Este repositório é uma cópia de trabalho independente do projeto original [YangJiiii/3105](https://github.com/YangJiiii/3105). O código-fonte não foi alterado para a compilação.

## Compilação

O projeto é um app iOS nativo em Swift/Objective-C e requer macOS, Xcode e o iOS SDK. O workflow [`Build iOS app`](.github/workflows/build-ios.yml) compila o target `3105` em configuração `Release` usando `xcodebuild` em um runner macOS do GitHub Actions.

O build usa `CODE_SIGNING_ALLOWED=NO` e `CODE_SIGNING_REQUIRED=NO`. Portanto, o resultado é um `.app` compilado e não assinado; ele não é uma IPA pronta para instalação. O artefato `3105-unsigned-ios-release` contém o app compactado e o log completo do Xcode por 14 dias.

## Verificação local

A compilação não pôde ser executada diretamente neste ambiente Linux porque `xcodebuild` e os SDKs Apple não estão disponíveis. O workflow macOS é a forma reproduzível de executar o build do projeto.

## Instalação em dispositivo

A instalação em dispositivo exige assinatura, provisionamento e os certificados apropriados. Esses materiais não fazem parte deste repositório e não foram adicionados ao novo repositório público.
