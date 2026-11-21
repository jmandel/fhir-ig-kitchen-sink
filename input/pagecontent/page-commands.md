This page is assembled by the publisher from commands embedded in the page source. Each section uses one
command; the output is regenerated on every build, so it is always exactly as accurate as the data.

### A resource fragment

The example patient, in JSON, without its narrative and with the extensions elided for brevity:

{% fragment Patient/alice JSON ELIDE:text|extension %}

The maturity observation, in XML:

{% fragment Observation/alice-maturity XML %}

### A table from JSON and Liquid

{% json input/includes/committee-roster.json input/includes/committee-roster.liquid %}

### Queries over the guide's own database

Code systems defined in this guide:

{% sql SELECT Name, Title, Web FROM Resources WHERE Type = 'CodeSystem' ORDER BY Name %}

Patients and their excuses, from a view definition:

{% sql SELECT id, family, excuse FROM patient_excuses ORDER BY id %}

### A multi-map

What the specification says, and what was implemented instead:

{% multi-map {"source": {"CodeSystem": "http://example.org/fhir/kitchen-sink/CodeSystem/spec-says", "title": "What the specification says"}, "columns": [{"type": "ConceptMap", "url": "http://example.org/fhir/kitchen-sink/ConceptMap/spec-to-reality", "title": "What was implemented"}], "caption": "Specification versus implementation"} %}

### A class diagram

The two logical models in this guide, and how one becomes the other:

{% class-diagram {"id": "spec-and-reality", "prefix": "sr", "attributes": true, "classes": ["InterfaceSpecification", "ImplementationReality"]} %}

### References by name

The profile for patients is [[[KitchenSinkPatient]]], and the version of this guide is [[[$ver]]].
