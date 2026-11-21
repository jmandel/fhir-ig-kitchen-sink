### Conformance

The requirements of this guide are stated in [the exchange requirements](Requirements-exchange.html). They are
all SHALL. Several have footnotes. Implementers are reminded that a footnote is part of the requirement, not a
loophole in it.

The actors are:

* [The Vendor Who Will Implement It Next Quarter](ActorDefinition-vendor-next-quarter.html)
* [The Integration Engine That Fixes Everything](ActorDefinition-integration-engine.html)
* [The Hypothetical Conformant Client](ActorDefinition-conformant-client.html)

Their obligations are stated on each profile, for example on the [Kitchen Sink Patient](StructureDefinition-ks-patient.html).

### Excuses

Where a system does not meet a requirement, it SHALL record why, using the
[Excuse extension](StructureDefinition-ext-excuse.html) and a code from [Accepted Excuses](ValueSet-excuses.html).
A workaround MAY carry a [severity](StructureDefinition-ext-workaround-severity.html).

### Testing

Conformance is tested by the conformance test plan (in , see the README), which in turn uses the
[read-patient test script](TestScript-read-patient.html). The test plan is executed before every release, in
principle.
