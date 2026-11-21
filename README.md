# fhir-ig-kitchen-sink

A small, synthetic FHIR Implementation Guide that exercises as many IG Publisher rendering features as
possible in a build of well under a minute. It is a test fixture: for publisher and template changes, for
replacements of the publisher's Jekyll stage (such as
[fhir-ig-jekyll](https://github.com/jmandel/fhir-ig-jekyll)), and for CI jobs that need a fast IG with
broad coverage instead of a slow real one.

The content is a treatise on "The Right Way To Exchange Health Data", which explains why most of the
examples describe excuses. All people, systems and organisations in it are invented.

## What is in it

| Directory | Guide | Package | FHIR | Notes |
|---|---|---|---|---|
| `.` | The Right Way To Exchange Health Data | `example.fhir.uv.kitchensink` | 5.0.0 | 65 resources plus generated ones (factory, ADL, datasets), 9 pages, English + German |
| `r4/` | the R4 companion ("classic") | `example.fhir.uv.kitchensinkclassic` | 4.0.1 | single language, cross-version extensions, additional-binding extensions |
| `input/extra/` | (main guide, opt-in) | | | resources that current publishers cannot build; see [Known publisher crashers](#known-publisher-crashers) |

Both guides use the template `fhir2.base.template#0.1.0` (the base template with translations, needed for
a two-language guide). The IG resources are plain JSON (`input/kitchen-sink.json`,
`r4/input/kitchen-sink-classic.json`); no SUSHI step. Canonical: `http://example.org/fhir/kitchen-sink`.
License: CC0-1.0.

## Building

Requirements: Java 17+, bash, tar, and an IG Publisher jar (any recent release, or a snapshot you built).
The publisher needs Jekyll on the PATH for its site step, or pass a drop-in with `-- -jekyll <path>`.

```sh
./build.sh -j publisher.jar -i all             # both guides, companion first (the main guide lists it as related-ig)
./build.sh -j publisher.jar                    # main guide only
./build.sh -j publisher.jar -i r4              # R4 companion only
./build.sh -j publisher.jar -t offline -n      # no terminology server, no network access (package cache must be warm)
./build.sh -j publisher.jar -d my-image -c cache-dir -w /local/work -i all -t offline -n   # in Docker, container without a network
./build.sh -j publisher.jar -a                 # also build input/extra (expect a publisher crash)
```

`build.sh` copies the source (a tar stream, so nothing is bind-mounted in Docker mode) into a work
directory and builds there; the source tree is never written to. Run `./build.sh` without arguments for all
options (`-w` work dir, `-m` heap, `-c` package cache, `-k` incremental rebuild, `-t record:/replay:/strict:`
terminology ledgers for publisher builds that support them, and extra publisher arguments after `--`).

Network use:

* Terminology: answers from tx.fhir.org are checked in (`input-cache/txcache`, `r4/input-cache/txcache`), so
  a live build sends few requests. `-t offline` runs with `-tx n/a` and needs no terminology server.
* Packages: the first build downloads the core packages, the template, `hl7.fhir.uv.extensions`,
  `hl7.fhir.uv.tools` and `openehr.base#current` (the ADL archetype's reference model). After that the
  build needs no network.
* `-n` passes the publisher's `-no-network` flag (and `--network none` in Docker mode). Without it, an
  offline build still works but waits for package-currency checks and usage statistics to time out: the
  R4 companion took 119 s instead of 12 s.

### Build times

Publisher 3.0.6-SNAPSHOT (master, 749d8d63) and 3.0.4; 6 GB heap; Docker on a Linux VM on a laptop; warm
package cache.

| Jar | Terminology / network | R4 companion | Main guide |
|---|---|---|---|
| master | live (cached answers) | 13–49 s | 32–46 s |
| master | `-t offline -n` | 12 s | 26 s |
| 3.0.4 | `-t offline -n` | 11 s | 28 s |

The live range is network variance. Of the main guide's time, the Jekyll stage is about 2 s (4,031 output
files; 0.4 s and 1,327 files for the companion).

### Expected QA result

Both jars give the same result: R4 companion 0 errors; main guide 8 errors, all publisher defects rather
than content errors:

* 2 broken links (one per language): the generated narrative of `Observation/alice-maturity` links to its
  contained resource as `#hcalice-maturity/assessor` (`#de-hc…` in German), and no such anchor is emitted.
* 6 errors in the StructureDefinition the publisher generates from the ADL archetype
  (`openEHR-EHR-CLUSTER.excuse.v1.0.0`): `view-hint` extensions with a value the extension forbids, a
  canonical `#concept` with no target, and sdf-9 on the root element.

## Feature coverage

Coverage is measured with `scripts/feature_scan.py` and `scripts/feature_matrix.py` from
[fhir-ig-jekyll](https://github.com/jmandel/fhir-ig-jekyll), run on a real build's `temp/pages` (the
publisher's Jekyll input) and the source tree. Its 76 feature ids come from a survey of the
features in use across the IGs on build.fhir.org. The same 67 are detected with publisher master (live or offline) and
3.0.4: 64 by the main guide and 3 more by the R4 companion.

| Feature id | Rendering feature | Exercised by | Detected |
|---|---|---|---|
| `questionnaire` | Questionnaire views (tree/form/links/logic/dict) | `Questionnaire/readiness` | main |
| `q-expansion` | Questionnaire answerValueSet / item.definition lookups | `Questionnaire/readiness` (answerValueSet, item.definition) | main |
| `qresponse` | QuestionnaireResponse tree/form | `QuestionnaireResponse/readiness-alice` | main |
| `structuremap` | StructureMap / FML | `input/maps/SpecToReality.fml` | main |
| `logical` | Logical models (kind=logical) | `StructureDefinition/InterfaceSpecification`, `ImplementationReality` | main |
| `uml` | UML / class diagrams (generate-uml, {% class-diagram %}, input/diagrams) | `generate-uml: source`; `{% class-diagram %}` on page-commands | main |
| `obligations` | Obligations on profiles | `StructureDefinition/ks-patient`, `ks-maturity-observation`; R4: `legacy-patient` | main |
| `obligation-actors` | Per-actor obligation fragments | obligations per `ActorDefinition` (generated fragments) | main |
| `actordefinition` | ActorDefinition | `ActorDefinition/conformant-client`, `integration-engine`, `vendor-next-quarter` | main |
| `requirements` | Requirements | `Requirements/exchange`, `vendor-commitments` | main |
| `adl` | ADL archetypes | `input/archetypes/openEHR-EHR-CLUSTER.excuse.v1.adl` (dependency `openehr.base`) | main |
| `testplan` | TestPlan | `input/extra/TestPlan-conformance.json` (opt-in, crashes the publisher) | no |
| `testscript` | TestScript | `TestScript/read-patient` | main |
| `capstmt` | CapabilityStatement | `CapabilityStatement/ks-base-server`, `ks-server`, `ks-messaging` | main |
| `capstmt-imports` | CapabilityStatement imports/instantiates | `CapabilityStatement/ks-server` imports `ks-base-server` | main |
| `capstmt-messaging` | CapabilityStatement messaging/document | `CapabilityStatement/ks-messaging` (messaging + document) | main |
| `opdef` | OperationDefinition | `OperationDefinition/generate-excuse` | main |
| `searchparam` | SearchParameter | `SearchParameter/patient-excuse`, `patient-excuse-severity`, `patient-severity-excuse` | main |
| `sp-composite` | Composite SearchParameter | `SearchParameter/patient-severity-excuse` | main |
| `conceptmap` | ConceptMap | `ConceptMap/spec-to-reality` | main |
| `cm-dependson` | ConceptMap dependsOn/product/unmapped | `ConceptMap/spec-to-reality` (dependsOn, product, unmapped) | main |
| `namingsystem` | NamingSystem | `NamingSystem/vendor-ticket` | main |
| `examplescenario` | ExampleScenario | `ExampleScenario/fax-roundtrip` | main |
| `bundle-document` | Document Bundles | `Bundle/fax-cover` (profile `ks-fax-document`) | main |
| `bundle-message` | Message Bundles | `Bundle/excuse-message` | main |
| `bundle-history` | History Bundles / Provenance history | `Bundle/alice-history` | main |
| `bundle-nested` | Bundles nested in Bundles | `Bundle/collected-evidence` | main |
| `library-cql` | Library with CQL (CqlSubSystem) | `Library/excuse-logic` + `input/cql/ExcuseLogic.cql` | main |
| `library` | Library (base-template Library.liquid) | `Library/excuse-logic` | main |
| `measure` | Measure (Measure.liquid) | `Measure/adoption` | main |
| `plandef` | PlanDefinition / ActivityDefinition (liquid) | `PlanDefinition/remediation`, `ActivityDefinition/escalate` | main |
| `own-liquid` | IG-authored Liquid narrative templates | `input/liquid/Device.liquid`, `input/includes/committee-roster.liquid`, factory template | main |
| `newml` | New multi-language mode, single language (lang-suffixed fragments, redirect wrappers) | R4 companion (single language, new multi-language layout) | R4 companion |
| `multilang` | Two or more languages (PublisherTranslator, per-language rendering passes) | en + de (`i18n-lang`) | main |
| `translation-files` | Translation source files (.po/.xliff) in the repo | `input/translations/de/*.po`, translated pages and menu | main |
| `translation-ext` | Translation extensions in content | translation extensions in `ks-patient`, `CodeSystem/interop-maturity` | main |
| `xver-ext` | Cross-version extensions used in resources (ProfileDrivenRenderer xver path) | R4: `Observation/carol-recheck` (5.0 `Observation.triggeredBy`), `ActorDefinition/legacy-system` | R4 companion |
| `prev-version` | Previous-version comparison | not covered: needs a published `package-list.json` at the canonical | no |
| `ipa-ips` | IPA / IPS comparison | not covered: needs a published previous version | no |
| `sd-changes` | Profile change summary (sd-changes non-empty) | not covered: needs a published previous version | no |
| `other-versions` | "Other versions" (R4/R4B/R5 inclusion) fragment non-empty | `generate-version` r4, r3 | main |
| `multi-version-params` | r4/r4b/r5 inclusion/exclusion or x-version params | `generate-version`, `conversion-version` | main |
| `diff-mappings` | Profile mappings in differential (maps/maps-classic) | `StructureDefinition/ks-patient` (differential mappings) | main |
| `imposes` | imposeProfile / compliesWithProfile | `StructureDefinition/ks-patient` (imposeProfile, compliesWithProfile) | main |
| `additional-binding` | Additional bindings | R4: `legacy-patient`, `legacy-observation` (extension form; R5 native form in the main guide is not counted by the scanner) | R4 companion |
| `custom-resource` | Custom resources (kind=resource specialization) | not covered: needs an approved custom-resource registration | no |
| `datatype-profile` | Datatype profiles | `StructureDefinition/ks-humanname` | main |
| `ext-on-ext` | Extensions on extensions (context type=extension) | `StructureDefinition/ext-workaround-severity` | main |
| `contentref` | contentReference in differential | `StructureDefinition/ImplementationReality` | main |
| `cs-supplement` | CodeSystem supplements | `CodeSystem/maturity-commentary` | main |
| `cs-fragment` | CodeSystem content fragment/not-present | `CodeSystem/excuses` | main |
| `vs-filter` | ValueSet with filters | `ValueSet/production-ready` | main |
| `vs-expansion` | ValueSet with stored expansion | `ValueSet/excuses` | main |
| `subscription` | SubscriptionTopic | `SubscriptionTopic/excuse-recorded` | main |
| `graphdef` | GraphDefinition | `GraphDefinition/excuse-graph` | main |
| `messagedef` | MessageDefinition | `MessageDefinition/excuse-notification` | main |
| `compartment` | CompartmentDefinition | `input/extra/CompartmentDefinition-device.json` (opt-in, crashes the publisher) | no |
| `evidence` | Evidence / EvidenceVariable / Citation | `input/extra/Citation-the-spec.json` (opt-in, crashes the publisher) | no |
| `group` | Group | `Group/committee` | main |
| `consent` | Consent | `Consent/share-maybe` | main |
| `provenance` | Provenance | `Provenance/alice-retyped` | main |
| `binary` | Binary | `Binary/fax-cover-sheet` | main |
| `parameters` | Parameters / OperationOutcome | `Parameters/excuse-result`, `OperationOutcome/not-yet` | main |
| `viewdef` | ViewDefinition / SQL ({% sql %}, DBBuilder) | `input/views/patient-excuses.json`, `{% sql %}` on page-commands | main |
| `dataset` | Datasets / test-data-factories | `input/datasets`, `input/factories`; `{% dataset %}` on respondents/respondent | main |
| `page-fragment` | {% fragment %} / {% json %} / {% multi-map %} page commands | `{% fragment %}`, `{% json %}`, `{% multi-map %}` on page-commands | main |
| `rendering-ext` | rendering-xhtml/markdown/style extensions | `Questionnaire/readiness` (rendering-xhtml, rendering-style), `Patient/bob` (rendering-markdown) | main |
| `narrativeless` | Examples without narrative (ProfileDrivenRenderer) | most examples have no `text` (e.g. `Patient/alice`) | main |
| `contained` | Contained resources | `Observation/alice-maturity` (contained Device) | main |
| `r5` | FHIR R5 / R6 IG | main guide (FHIR 5.0.0) | main |
| `r4b` | FHIR R4B IG | not covered: would need an R4B companion | no |
| `stu3` | FHIR STU3 IG | not covered: would need an STU3 companion | no |
| `pin-canonicals` | pin-canonicals / pin-manifest | `pin-canonicals: pin-multiples` | main |
| `special-url` | special-url / instance-hyperlinks | `special-url` | main |
| `profile-test-cases` | profile-test-cases | `input/profile-tests/profile-tests.json` | main |
| `related-ig` | related-ig | `related-ig` → the R4 companion | main |

Not covered, and why:

* `testplan`, `compartment`, `evidence`: the resources are in `input/extra/` and crash the publisher (below).
* `prev-version`, `ipa-ips`, `sd-changes`: need a previously published version (a `package-list.json` at the
  canonical), which a self-contained fixture does not have.
* `custom-resource`: custom resources must be registered in the IG registry's approval list.
* `r4b`, `stu3`: would need more companion guides.

The scanner counts some features from the source tree (`.po`, `.fml`, `.cql`, `.liquid`, `.adl` files and
page tags), so check the rendered output when a change might silently drop one.

## Known publisher crashers

`input/extra/` holds valid resources that current publishers (3.0.4 and master) cannot build. They are
left out unless you pass `-a`, which is meant for testing a publisher fix.

| File | Failure |
|---|---|
| `TestPlan-conformance.json` | the load aborts: "The resource TestPlan cannot be converted from R5 to RN" |
| `Citation-the-spec.json` | the load aborts the same way: the R5 → other-version converter has no Citation, Evidence or EvidenceVariable |
| `CompartmentDefinition-device.json` | Generate Native Outputs dies with `java.lang.Error` "The resource type CompartmentDefinition does not implement the property copyright" (`DBBuilder.insertCanonicalResource`) |

Two more defects shaped the layout:

* The test-data factory output directory is also declared as a `path-resource`: with only `path-factory`,
  the loader keeps the factory directories as its resource directories and then cannot find later
  IG-listed resources.
* `input/maps/SpecToReality.fml` is found by the publisher on its own. Listing it in the IG resource as
  `StructureMap/<id>` gives a NullPointerException (the file has no content type).

## Layout notes

* The publisher writes into the IG folder (`translations/`, `input/profile-tests/*.out.json`,
  `input/factories/log/`, `input/factory-output/`); these are gitignored, and `build.sh` builds in a copy
  anyway.
* `input/ignoreWarnings.txt` suppresses nothing: warnings are part of what the guide exercises.
