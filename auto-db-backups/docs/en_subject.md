Automated DB Backups
Setup a scheduled workflow to backup a Database every 12 hours

The goal of this project is to set up a scheduled workflow to back up a Database every 12 hours and upload the backup to Cloudflare R2, which has a free tier for storage.

Requirements
The prerequisite for this project is to have a server set up and a database ready to back up. You can use one of the projects did in the other project. Alternatively:

Set up a server on Digital Ocean or any other provider

Run a MongoDB instance on the server

Seed some data into the database

Once you have a server and a database ready, you can proceed to the next step.

Scheduled Backups
You can do this bit either by setting up a cron job on the server or setting up a scheduled workflow in Github Actions that runs every 12 hours and executes the backup from there. The database should be backed up into a tarball and uploaded to Clouodflare R2.

Hint: You can use the mongodump to dump the database and then use aws cli to upload the file to R2.

Stretch Goal
Write a script to download the latest backup from R2 and restore the database.

Database backups are essential to ensure that you can restore your data in case of a disaster. This project will give you hands-on experience on how to set up a scheduled workflow to back up a database and how to restore it from a backup.
