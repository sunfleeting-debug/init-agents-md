# Java Project Detection

## Identification

- `pom.xml` exists → Maven project.
- `build.gradle` exists → Gradle project (Groovy DSL).
- `build.gradle.kts` exists → Gradle project (Kotlin DSL).

## Characterization (Maven)

Parse with Python's `xml.etree.ElementTree`, namespace `m: http://maven.apache.org/POM/4.0.0`:

- **buildTool**: maven.
- **javaVersion**: `properties.java.version`.
- **springBootVersion**: if `parent.artifactId == "spring-boot-starter-parent"`,
  read `parent.version`.
- **framework**: `spring-boot` if springBootVersion is set; else `none`.
- **mainDeps**: list of `dependencies.dependency.artifactId`.
- **testCommand**: `mvn test`.
- **buildCommand**: `mvn package`.
- **lintCommand**: not auto-detected in v1; manual override.
- **formatCommand**: not auto-detected in v1.

## Characterization (Gradle)

Grep `build.gradle` for `JavaVersion.VERSION_<N>` or `sourceCompatibility = "<N>"`.
Use a more complete Gradle parser in v2.

## Edge cases

- Multi-module Maven project (parent pom with `<modules>`): treat parent dir
  as root; collect modules as workspace entries.
- Gradle wrapper present (`gradlew`): prefer `gradlew` over `gradle` in commands.
