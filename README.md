# Raktabija

Raktabija bootstraps a new AWS account with a vpc and autoscaling group containing a host that includes:

* A concourse instance that can run terraform. All further changes to the environment will be made through this mechanism.
* A cron job that runs the scripts to delete any AWS resources not included in [Chandika](https://github.com/18F/chandika)

In future, support will be added to run Chaos Monkey against the AWS account.

## The origin of the name Raktabija

The demon Raktabija had a superpower that meant that when a drop of his blood hit the ground, a new duplicate Raktabija would be created. Thus when the goddess Kali fought him, every time she wounded him, multiple new Raktabijas would be created. The goddess Chandika helped Kali kill all the clone Raktabijas and eventually killed Raktabija himself. The Chandika app is designed to help you kill the profusion of unused virtual resources that accumulate in a typical cloud environment.

# Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
