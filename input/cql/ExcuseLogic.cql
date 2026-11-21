library ExcuseLogic version '0.2.0'

parameter "Release Date" Date default @2026-12-31

define "Days Until Release":
  difference in days between Today() and "Release Date"

define "Will Be Implemented":
  "Days Until Release" > 90

define "Excuse":
  if "Will Be Implemented" then 'next-quarter' else 'optional'
