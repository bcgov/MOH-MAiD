call sfdx force:org:create -v devhub -a maid-dev -f config/project-scratch-def.json -d 7 -s
call sfdx force:source:push -u maid-dev