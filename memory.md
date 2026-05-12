# DG App - Session History

## Session 1: 2026-04-24
Reviewed services in app/services/, discovered 5 bugs:
- prow_search_service.rb: params undefined
- import_etilab_service.rb: lastNum vs lastnum variable mismatch
- import_eticamp_service.rb: Etilab reference should be Eticamp
- create_qr_service.rb: returns nil (QR PNG not returned)
- check_qr_code_service.rb: empty stub

Reviewed core models: Prow, Tempesta, Proforma
Created structure.md with full app documentation

## Session 2: [date]
[TODO - add content]
