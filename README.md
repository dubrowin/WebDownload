# WebDownload
An AWS solution that uses Lambdas and SQS to download content for me.

I have a number of functions that I wanted/needed to be downloaded from the Internet and pushed to me on a regular basis.
Previously, I had this done for me via scripts running on-prem (aka, at my house), but wanted something more robust.

![Architectural Diagram](https://github.com/dubrowin/WebDownload/blob/master/Webdownloader.png)

Going through the architecture left to right:

* **Inputs** - I currently have 2 Lambdas that are inputs to the Download Queue (SQS). 
** One is my podcatcher
** The other finds the next lesson for me in my Gemara/Talmud

These Inputs find URLs and push a message like into the SQS Queue:

 ```
{ "Destination" : "Podcast", "URL": "https://url.goes.here/foobar.mp3" }
```

* **Main Function**

The Lambda parses the SQS data, uses the Destination for the Target Directory (I'm pushing to Dropbox via the API) and the URL is downloaded.

My Lambda is written in bash and uses this bash lambda layer. 
* https://github.com/gkrizek/bash-lambda-layer
* (Note: I have an agreement with a friend that when my personal workloads have been all added to the cloud to go back and re-write all my bash lambdas is something like python).

* **Outputs**

* I currently send the data to Dropbox for the sync to my end devices
* And I send a message to a PushBullet SQS Queue which notifies me that there is a new file available.

## Background

I started to use BashPodder (https://lincgeek.org/bashpodder/) probablyl around 14 years ago. I started by running it on my home machine and having a simple apache webpage internally that I would download my podcasts from every morning. At some point, I started to push the mp3s to Dropbox and later added a DropSync so my device(s) could download everything automatically. My single installation eventually grew to include a multi-site installation and I used Dropbox as a quorum disk to determine which system would perform the work. Later this was updated to be an SQS queue and when 1 of the machines died, it was time to finally move to serverless in the cloud. I wrote a bash Dropbox API library (https://github.com/dubrowin/DropboxAPI) that I use to upload my content to Dropbox via the API. The API documentation is excellent (https://www.dropbox.com/developers/documentation/http/documentation) with examples in multiple languages.
