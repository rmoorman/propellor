-- This is the live config file used by propellor's author.
-- https://propellor.branchable.com/
module Main where

import Propellor
import Propellor.CmdLine
import Propellor.Property.Scheduled
import qualified Propellor.Property.File as File
import qualified Propellor.Property.Apt as Apt
import qualified Propellor.Property.Network as Network
import qualified Propellor.Property.Service as Service
import qualified Propellor.Property.Ssh as Ssh
import qualified Propellor.Property.Cron as Cron
import qualified Propellor.Property.Sudo as Sudo
import qualified Propellor.Property.User as User
import qualified Propellor.Property.Hostname as Hostname
import qualified Propellor.Property.Tor as Tor
import qualified Propellor.Property.Dns as Dns
import qualified Propellor.Property.OpenId as OpenId
import qualified Propellor.Property.Docker as Docker
import qualified Propellor.Property.Git as Git
import qualified Propellor.Property.Postfix as Postfix
import qualified Propellor.Property.Grub as Grub
import qualified Propellor.Property.Obnam as Obnam
import qualified Propellor.Property.Gpg as Gpg
import qualified Propellor.Property.Systemd as Systemd
import qualified Propellor.Property.Journald as Journald
import qualified Propellor.Property.OS as OS
import qualified Propellor.Property.HostingProvider.CloudAtCost as CloudAtCost
import qualified Propellor.Property.HostingProvider.Linode as Linode
import qualified Propellor.Property.SiteSpecific.GitHome as GitHome
import qualified Propellor.Property.SiteSpecific.GitAnnexBuilder as GitAnnexBuilder
import qualified Propellor.Property.SiteSpecific.IABak as IABak
import qualified Propellor.Property.SiteSpecific.JoeySites as JoeySites


main :: IO ()           --     _         ______`|                       ,-.__ 
main = defaultMain hosts --  /   \___-=O`/|O`/__|                      (____.'
  {- Propellor            -- \          / | /    )          _.-"-._
     Deployed -}          --  `/-==__ _/__|/__=-|          (       \_
hosts :: [Host]          --   *             \ | |           '--------'
hosts =                --                  (o)  `
	[ darkstar
	, gnu
	, clam
	, orca
	, kite
	, elephant
	, beaver
	, iabak
	] ++ monsters

testvm :: Host
testvm = host "testvm.kitenet.net"
	& os (System (Debian Unstable) "amd64")
	& OS.cleanInstallOnce (OS.Confirmed "testvm.kitenet.net")
	 	`onChange` propertyList "fixing up after clean install"
	 		[ OS.preserveRootSshAuthorized
			, OS.preserveResolvConf
			, Apt.update
			, Grub.boots "/dev/sda"
				`requires` Grub.installed Grub.PC
	 		]
	& Hostname.sane
	& Hostname.searchDomain
	& Apt.installed ["linux-image-amd64"]
	& Apt.installed ["ssh"]
	& User.hasPassword (User "root")

darkstar :: Host
darkstar = host "darkstar.kitenet.net"
	& ipv6 "2001:4830:1600:187::2" -- sixxs tunnel

	& Apt.buildDep ["git-annex"] `period` Daily
	& Docker.configured
	! Docker.docked gitAnnexAndroidDev

	& JoeySites.postfixClientRelay (Context "darkstar.kitenet.net")
	& JoeySites.dkimMilter

gnu :: Host
gnu = host "gnu.kitenet.net"
	& Apt.buildDep ["git-annex"] `period` Daily
	& Docker.configured

	& JoeySites.postfixClientRelay (Context "gnu.kitenet.net")
	& JoeySites.dkimMilter

clam :: Host
clam = standardSystem "clam.kitenet.net" Unstable "amd64"
	[ "Unreliable server. Anything here may be lost at any time!" ]
	& ipv4 "167.88.41.194"

	& CloudAtCost.decruft
	& Ssh.randomHostKeys
	& Apt.unattendedUpgrades
	& Network.ipv6to4
	& Tor.isRelay
	& Tor.named "kite1"
	& Tor.bandwidthRate (Tor.PerMonth "400 GB")

	& Docker.configured
	& Docker.garbageCollected `period` Daily
	& Docker.docked webserver
	& File.dirExists "/var/www/html"
	& File.notPresent "/var/www/html/index.html"
	& "/var/www/index.html" `File.hasContent` ["hello, world"]
	& alias "helloworld.kitenet.net"
	& Docker.docked oldusenetShellBox

	& JoeySites.scrollBox
	& alias "scroll.joeyh.name"
	& alias "us.scroll.joeyh.name"
	
	-- ssh on some extra ports to deal with horrible networks
	-- while travelling
	& alias "travelling.kitenet.net"
	! Ssh.listenPort 80
	! Ssh.listenPort 443

	& Systemd.persistentJournal

orca :: Host
orca = standardSystem "orca.kitenet.net" Unstable "amd64"
	[ "Main git-annex build box." ]
	& ipv4 "138.38.108.179"

	& Apt.unattendedUpgrades
	& Postfix.satellite
	& Systemd.persistentJournal
	& Docker.configured
	& Docker.docked (GitAnnexBuilder.standardAutoBuilderContainer dockerImage "amd64" 15 "2h")
	& Docker.docked (GitAnnexBuilder.standardAutoBuilderContainer dockerImage "i386" 45 "2h")
	& Docker.docked (GitAnnexBuilder.armelCompanionContainer dockerImage)
	& Docker.docked (GitAnnexBuilder.armelAutoBuilderContainer dockerImage (Cron.Times "1 3 * * *") "5h")
	& Docker.docked (GitAnnexBuilder.androidAutoBuilderContainer dockerImage (Cron.Times "1 1 * * *") "3h")
	& Docker.garbageCollected `period` Daily
	& Apt.buildDep ["git-annex"] `period` Daily

-- This is not a complete description of kite, since it's a
-- multiuser system with eg, user passwords that are not deployed
-- with propellor.
kite :: Host
kite = standardSystemUnhardened "kite.kitenet.net" Testing "amd64"
	[ "Welcome to kite!" ]
	& ipv4 "66.228.36.95"
	& ipv6 "2600:3c03::f03c:91ff:fe73:b0d2"
	& alias "kitenet.net"
	& alias "wren.kitenet.net" -- temporary
	& Ssh.hostKeys (Context "kitenet.net")
		[ (SshDsa, "ssh-dss AAAAB3NzaC1kc3MAAACBAO9tnPUT4p+9z7K6/OYuiBNHaij4Nzv5YVBih1vMl+ALz0gYAj8RWJzXmqp5buFAyfgOoLw+H9s1bBS01Sy3i07Dm6cx1fWG4RXL/E/3w1tavX99GD2bBxDBu890ebA5Tp+eFRJkS9+JwSvFiF6CP7NbVjifCagoUO56Ig048RwDAAAAFQDPY2xM3q6KwsVQliel23nrd0rV2QAAAIEAga3hj1hL00rYPNnAUzT8GAaSP62S4W68lusErH+KPbsMwFBFY/Ib1FVf8k6Zn6dZLh/HH/RtJi0JwdzPI1IFW+lwVbKfwBvhQ1lw9cH2rs1UIVgi7Wxdgfy8gEWxf+QIqn62wG+Ulf/HkWGvTrRpoJqlYRNS/gnOWj9Z/4s99koAAACBAM/uJIo2I0nK15wXiTYs/NYUZA7wcErugFn70TRbSgduIFH6U/CQa3rgHJw9DCPCQJLq7pwCnFH7too/qaK+czDk04PsgqV0+Jc7957gU5miPg50d60eJMctHV4eQ1FpwmGGfXxRBR9k2ZvikWYatYir3L6/x1ir7M0bA9IzNU45")
		, (SshRsa, "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAIEA2QAJEuvbTmaN9ex9i9bjPhMGj+PHUYq2keIiaIImJ+8mo+yKSaGUxebG4tpuDPx6KZjdycyJt74IXfn1voGUrfzwaEY9NkqOP3v6OWTC3QeUGqDCeJ2ipslbEd9Ep9XBp+/ldDQm60D0XsIZdmDeN6MrHSbKF4fXv1bqpUoUILk=")
		, (SshEcdsa, "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLF+dzqBJZix+CWUkAd3Bd3cofFCKwHMNRIfwx1G7dL4XFe6fMKxmrNetQcodo2edyufwoPmCPr3NmnwON9vyh0=")
		, (SshEd25519, "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFZftKMnH/zH29BHMKbcBO4QsgTrstYFVhbrzrlRzBO3")
		]

	& Network.static "eth0" `requires` Network.cleanInterfacesFile
	& Apt.installed ["linux-image-amd64"]
	& Linode.chainPVGrub 5
	& Linode.mlocateEnabled
	& Apt.unattendedUpgrades
	& Systemd.installed
	& Systemd.persistentJournal
	& Journald.systemMaxUse "500MiB"
	& Ssh.passwordAuthentication True
	-- Since ssh password authentication is allowed:
	& Apt.serviceInstalledRunning "fail2ban"
	& Obnam.backupEncrypted "/" (Cron.Times "33 1 * * *")
		[ "--repository=sftp://joey@eubackup.kitenet.net/~/lib/backup/kite.obnam"
		, "--client-name=kitenet.net"
		, "--exclude=/var/cache"
		, "--exclude=/var/tmp"
		, "--exclude=/home/joey/lib"
		, "--exclude=.*/tmp/"
		, "--one-file-system"
		] Obnam.OnlyClient (Gpg.GpgKeyId "98147487")
		`requires` Ssh.keyImported SshRsa (User "root")
			(Context "kite.kitenet.net")
		`requires` Ssh.knownHost hosts "eubackup.kitenet.net" (User "root")
	& Apt.serviceInstalledRunning "ntp"
	& "/etc/timezone" `File.hasContent` ["US/Eastern"]

	& alias "smtp.kitenet.net"
	& alias "imap.kitenet.net"
	& alias "pop.kitenet.net"
	& alias "mail.kitenet.net"
	& JoeySites.kiteMailServer
	
	& JoeySites.kitenetHttps
	& JoeySites.legacyWebSites
	& File.ownerGroup "/srv/web" (User "joey") (Group "joey")
	& Apt.installed ["analog"]
	
	& alias "git.kitenet.net"
	& alias "git.joeyh.name"
	& JoeySites.gitServer hosts

	& JoeySites.downloads hosts
	& JoeySites.gitAnnexDistributor
	& JoeySites.tmp

	& alias "bitlbee.kitenet.net"
	& Apt.serviceInstalledRunning "bitlbee"
	& "/etc/bitlbee/bitlbee.conf" `File.hasContent`
		[ "[settings]"
		, "User = bitlbee"
		, "AuthMode = Registered"
		, "[defaults]"
		] 
		`onChange` Service.restarted "bitlbee"
	& "/etc/default/bitlbee" `File.containsLine` "BITLBEE_PORT=\"6767\""
		`onChange` Service.restarted "bitlbee"

	& Apt.installed
		[ "git-annex", "myrepos"
		, "build-essential", "make"
		, "rss2email", "archivemail"
		, "devscripts"
		-- Some users have zsh as their login shell.
		, "zsh"
		]
	
	& Docker.configured
	& Docker.garbageCollected `period` Daily
	
	& alias "nntp.olduse.net"
	& JoeySites.oldUseNetServer hosts
	
	& alias "ns4.kitenet.net"
	& myDnsPrimary True "kitenet.net" []
	& myDnsPrimary True "joeyh.name" []
	& myDnsPrimary True "ikiwiki.info" []
	& myDnsPrimary True "olduse.net"
		[ (RelDomain "article", CNAME $ AbsDomain "virgil.koldfront.dk")
		]
	& alias "ns4.branchable.com"
	& branchableSecondary
	& Dns.secondaryFor ["animx"] hosts "animx.eu.org"

elephant :: Host
elephant = standardSystem "elephant.kitenet.net" Unstable "amd64"
	[ "Storage, big data, and backups, omnomnom!"
	, "(Encrypt all data stored here.)"
	]
	& ipv4 "193.234.225.114"
	& Ssh.hostKeys hostContext
		[ (SshDsa, "ssh-dss AAAAB3NzaC1kc3MAAACBANxXGWac0Yz58akI3UbLkphAa8VPDCGswTS0CT3D5xWyL9OeArISAi/OKRIvxA4c+9XnWtNXS7nYVFDJmzzg8v3ZMx543AxXK82kXCfvTOc/nAlVz9YKJAA+FmCloxpmOGrdiTx1k36FE+uQgorslGW/QTxnOcO03fDZej/ppJifAAAAFQCnenyJIw6iJB1+zuF/1TSLT8UAeQAAAIEA1WDrI8rKnxnh2rGaQ0nk+lOcVMLEr7AxParnZjgC4wt2mm/BmkF/feI1Fjft2z4D+V1W7MJHOqshliuproxhFUNGgX9fTbstFJf66p7h7OLAlwK8ZkpRk/uV3h5cIUPel6aCwjL5M2gN6/yq+gcCTXeHLq9OPyUTmlN77SBL71UAAACBAJJiCHWxPAGooe7Vv3W7EIBbsDyf7b2kDH3bsIlo+XFcKIN6jysBu4kn9utjFlrlPeHUDzGQHe+DmSqTUQQ0JPCRGcAcuJL8XUqhJi6A6ye51M9hVt51cJMXmERx9TjLOP/adkEuxpv3Fj20FxRUr1HOmvRvewSHrJ1GeA1bjbYL")
		, (SshRsa, "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrEQ7aNmRYyLKY7xHILQsyV/w0B3++D98vn5IvjHkDnitrUWjB+vPxlS7LYKLzN9Jx7Hb14R2lg7+wdgtFMxLZZukA8b0tqFpTdRFBvBYGh8IM8Id1iE/6io/NZl+hTQEDp0LJP+RljH1CLfz7J3qtc+v6NbfTP5cOgH104mWYoLWzJGaZ4p53jz6THRWnVXy5nPO3dSBr2f/SQgRuJQWHNIh0jicRGD8H2kzOQzilpo+Y46PWtkufl3Yu3UsP5UMAyLRIXwZ6nNRZqRiVWrX44hoNfDbooTdFobbHlqMl+y6291bOXaOA6PACk8B4IVcC89/gmc9Oe4EaDuszU5kD")
		, (SshEcdsa, "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAJkoPRhUGT8EId6m37uBdYEtq42VNwslKnc9mmO+89ody066q6seHKeFY6ImfwjcyIjM30RTzEwftuVNQnbEB0=")
		, (SshEd25519, "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB6VtXi0uygxZeCo26n6PuCTlSFCBcwRifv6N8HdWh2Z")
		]

	& Grub.chainPVGrub "hd0,0" "xen/xvda1" 30
	& Postfix.satellite
	& Apt.unattendedUpgrades
	& Systemd.installed
	& Systemd.persistentJournal
	& Ssh.keyImported SshRsa (User "joey") hostContext
	& Apt.serviceInstalledRunning "swapspace"

	& alias "eubackup.kitenet.net"
	& Apt.installed ["obnam", "sshfs", "rsync"]
	& JoeySites.obnamRepos ["pell", "kite"]
	& JoeySites.githubBackup
	& JoeySites.rsyncNetBackup hosts

	& alias "podcatcher.kitenet.net"
	& JoeySites.podcatcher
	
	& alias "znc.kitenet.net"
	& JoeySites.ircBouncer
	& alias "kgb.kitenet.net"
	& JoeySites.kgbServer
	
	& alias "mumble.kitenet.net"
	& JoeySites.mumbleServer hosts
	
	& alias "ns3.kitenet.net"
	& myDnsSecondary
	
	& Docker.configured
	& Docker.docked oldusenetShellBox
	& Docker.docked openidProvider
		`requires` Apt.serviceInstalledRunning "ntp"
	& Docker.docked ancientKitenet
	& Docker.docked jerryPlay
	& Docker.garbageCollected `period` (Weekly (Just 1))
	
	& JoeySites.scrollBox
	& alias "scroll.joeyh.name"
	& alias "eu.scroll.joeyh.name"
	
	-- For https port 443, shellinabox with ssh login to
	-- kitenet.net
	& alias "shell.kitenet.net"
	& Docker.docked kiteShellBox
	-- Nothing is using http port 80, so listen on
	-- that port for ssh, for traveling on bad networks that
	-- block 22.
	& Ssh.listenPort 80

beaver :: Host
beaver = host "beaver.kitenet.net"
	& ipv6 "2001:4830:1600:195::2"
	& Apt.serviceInstalledRunning "aiccu"
	& Apt.installed ["ssh"]
	& Ssh.pubKey SshDsa "ssh-dss AAAAB3NzaC1kc3MAAACBAIrLX260fY0Jjj/p0syNhX8OyR8hcr6feDPGOj87bMad0k/w/taDSOzpXe0Wet7rvUTbxUjH+Q5wPd4R9zkaSDiR/tCb45OdG6JsaIkmqncwe8yrU+pqSRCxttwbcFe+UU+4AAcinjVedZjVRDj2rRaFPc9BXkPt7ffk8GwEJ31/AAAAFQCG/gOjObsr86vvldUZHCteaJttNQAAAIB5nomvcqOk/TD07DLaWKyG7gAcW5WnfY3WtnvLRAFk09aq1EuiJ6Yba99Zkb+bsxXv89FWjWDg/Z3Psa22JMyi0HEDVsOevy/1sEQ96AGH5ijLzFInfXAM7gaJKXASD7hPbVdjySbgRCdwu0dzmQWHtH+8i1CMVmA2/a5Y/wtlJAAAAIAUZj2US2D378jBwyX1Py7e4sJfea3WSGYZjn4DLlsLGsB88POuh32aOChd1yzF6r6C2sdoPBHQcWBgNGXcx4gF0B5UmyVHg3lIX2NVSG1ZmfuLNJs9iKNu4cHXUmqBbwFYQJBvB69EEtrOw4jSbiTKwHFmqdA/mw1VsMB+khUaVw=="
	& alias "usbackup.kitenet.net"
	& JoeySites.backupsBackedupFrom hosts "eubackup.kitenet.net" "/home/joey/lib/backup"
	& Apt.serviceInstalledRunning "anacron"
	& Cron.niceJob "system disk backed up" Cron.Weekly (User "root") "/"
		"rsync -a -x / /home/joey/lib/backup/beaver.kitenet.net/"

iabak :: Host
iabak = host "iabak.archiveteam.org"
	& ipv4 "124.6.40.227"
	& Hostname.sane
	& os (System (Debian Testing) "amd64")
	& Systemd.persistentJournal
	& Cron.runPropellor (Cron.Times "30 * * * *")
	& Apt.stdSourcesList `onChange` Apt.upgrade
	& Apt.installed ["git", "ssh"]
	& Ssh.hostKeys (Context "iabak.archiveteam.org")
		[ (SshDsa, "ssh-dss AAAAB3NzaC1kc3MAAACBAMhuYTshLxavWCpfyJxg3j/GWyIRlL3VTharsfUTzMOqyMSWantZjflfJX21z2KzFDtPEA711GYztsgMVXMrsPQInaOKNISe/R9cfgnEktKTxeppWTfw0GTNcpCeeecddU0FCPVW3a6yDoT6+Rv0jPvkQoDGmhQ40MhauMrO0mJ9AAAAFQDpCbXG8o/3Sg7wrsp5abizJoQ0yQAAAIEAxxyHo/ZhDPP+EWtDS05s5dwiDMUsxIllk1NeleAOQIyLtFkaifOeskDJybIPWYPGX1trjcPoGuXJ5GBYrRaPiu6FBvYdYMFRLr4uNBsaSHHqlHhBPkP3RzCrdUyau4XyjdE4iA0EQlO+u11A+o3f7aTuJSveM0YRfbqvaatG89EAAACAWd0h0SkRLnGjBzkou0SQfYujFY9ilhWXPWV/oOs+bieDSpvfmnaEfLSinVFRrJPvQp/dtpxPLEm+StrK3w6dmwTZVUM5JEoB1mRjBkVs6gPC9PVVg9qLpzC2/x+r5cTfrffjyRrlPdkwLKpO6oiPxTIxAyCW8ixjafkxe2hAeJo=")
		, (SshRsa, "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDP13oPRLRY0V9ZDWojb8TgHbUdE30Nq3b541TwPmlLMbYPAhldxGHkuXGlX8g9/FYP/1AgkPcxs2Uc61ZV+1Ss7q7t52f4R0bO4WHqxfdXHd9FlLzMLWxMU3aMr693pGlhnUp3/xH6O6/+bNEIo3VGGgv9XDr2cAxypS9J7X9ibHZcZ3BGvoCR+nnFJ00ERG2tREKZBPDWKk76lhCiM21fG/CSmcApXaA45FHDaM9/2Clj1sXvoS72f0hEKpl1m08sUx+F0GPzQESnKqNFl+xXdYPPbfhdrgCnDmx9tL5NnXsJU2beFiuxpICOeB1HV6DJsdlO18WqwXYhOg/2A1H3")
		, (SshEcdsa, "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHb0kXcrF5ThwS8wB0Hez404Zp9bz78ZxEGSqnwuF4d/N3+bymg7/HAj7l/SzRoEXKHsJ7P5320oMxBHeM16Y+k=")
		]
	& Apt.installed ["etckeeper", "sudo"]
	& Apt.installed ["vim", "screen", "tmux", "less", "emax-nox", "netcat"]
	& User.hasSomePassword (User "root")
	& propertyList "admin accounts"
		(map User.accountFor admins ++ map Sudo.enabledFor admins)
	& User.hasSomePassword (User "joey")
	& GitHome.installedFor (User "joey")
	& Ssh.authorizedKey (User "db48x") "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAIAQDQ6urXcMDeyuFf4Ga7CuGezTShKnEMPHKJm7RQUtw3yXCPX5wnbvPS2+UFnHMzJvWOX5S5b/XpBpOusP0jLpxwOCEg4nA5b7uvWJ2VIChlMqopYMo+tDOYzK/Q74MZiNWi2hvf1tn3N9SnqOa7muBMKMENIX5KJdH8cJ/BaPqAP883gF8r2SwSZFvaB0xYCT/CIylC593n/+0+Lm07NUJIO8jil3n2SwXdVg6ib65FxZoO86M46wTghnB29GXqrzraOg+5DY1zzCWpIUtFwGr4DP0HqLVtmAkC7NI14l1M0oHE0UEbhoLx/a+mOIMD2DuzW3Rs3ZmHtGLj4PL/eBU8D33AqSeM0uR/0pEcoq6A3a8ixibj9MBYD2lMh+Doa2audxS1OLM//FeNccbm1zlvvde82PZtiO11P98uN+ja4A+CfgQU5s0z0wikc4gXNhWpgvz8DrOEJrjstwOoqkLg2PpIdHRw7dhpp3K1Pc+CGAptDwbKkxs4rzUgMbO9DKI7fPcXXgKHLLShMpmSA2vsQUMfuCp2cVrQJ+Vkbwo29N0Js5yU7L4NL4H854Nbk5uwWJCs/mjXtvTimN2va23HEecTpk44HDUjJ9NyevAfPcO9q1ZtgXFTQSMcdv1m10Fvmnaiy8biHnopL6MBo1VRITh5UFiJYfK4kpTTg2vSspii/FYkkYOAnnZtXZqMehP7OZjJ6HWJpsCVR2hxP3sKOoQu+kcADWa/4obdp+z7gY8iMMjd6kwuIWsNV8KsX+eVJ4UFpAi/L00ZjI2B9QLVCsOg6D1fT0698wEchwUROy5vZZJq0078BdAGnwC0WGLt+7OUgn3O2gUAkb9ffD0odbZSqq96NCelM6RaHA+AaIE4tjGL3lFkyOtb+IGPNACQ73/lmaRQd6Cgasq9cEo0g22Ew5NQi0CBuu1aLDk7ezu3SbU09eB9lcZ+8lFnl5K2eQFeVJStFJbJNfOvgKyOb7ePsrUFF5GJ2J/o1F60fRnG64HizZHxyFWkEOh+k3i8qO+whPa5MTQeYLYb6ysaTPrUwNRcSNNCcPEN8uYOh1dOFAtIYDcYA56BZ321yz0b5umj+pLsrFU+4wMjWxZi0inJzDS4dVegBVcRm0NP5u8VRosJQE9xdbt5K1I0khzhrEW1kowoTbhsZCaDHhL9LZo73Z1WIHvulvlF3RLZip5hhtQu3ZVkbdV5uts8AWaEWVnIu9z0GtQeeOuseZpT0u1/1xjVAOKIzuY3sB7FKOaipe8TDvmdiQf/ICySqqYaYhN6GOhiYccSleoX6yzhYuCvzTgAyWHIfW0t25ff1CM7Vn+Vo9cVplIer1pbwhZZy4QkROWTOE+3yuRlQ+o6op4hTGdAZhjKh9zkDW7rzqQECFrZrX/9mJhxYKjhpkk0X3dSipPt9SUHagc4igya+NgCygQkWBOQfr4uia0LcwDxy4Kchw7ZuypHuGVZkGhNHXS+9JdAHopnSqYwDMG/z1ys1vQihgER0b9g3TchvGF+nmHe2kbM1iuIYMNNlaZD1yGZ5qR7wr/8dw8r0NBEwzsUfak3BUPX7H6X0tGS96llwUxmvQD85WNNoef0uryuAtDEwWlfN1RmWysZDc57Rn4gZi0M5jXmQD23ZiYXYBcG849OeqNzlxONEFsForXO/29Ud4x/Hqa9tf+kJbqMRsaLFO+PXhHzgl6ZHLAljQDxrJ6keNnkqaYfqQ8wyRi1mKv4Ab57kde7mUsZhe7w93GaE9Lxfvu7d3pB+lXfI9NJCSITHreUP4JfmFW+p/eVg+r/1wbElNylGna4I4+qYObOUncGwFKYdFPdtU1XLDKXmywTEgbEh7iI9zX0xD3bPHQLMg+TTtXiU9dQm1x/0zRf9trwDsRDJCbG4/P4iQYkcVvYx2CCfi0JSHv8tWsLi3GJKJLXUxZyzfvY2lThPeYnnY/HFrPJCyJUN55QuRmfzbu8rHgWlcyOlVpKtz+7kn823kEQykiIYKIKrb0G6VBzuMtAk9XzJPv+Wu7suOGXHlVfCqPLk6RjHDm4kTYciW9VgxDts5Y+zwcAbrUeA4UuN/6KisWpivMrfDSIHUCeH/lHBtNkqKohdrUKJMEOx5X6r2dJbmoTFBDi5XtYu/5cBtiDMmupNB0S+pZ2JD5/RKtj6kgzTeE1q/OG4q/eq1O1rjf0vIS31luy27K/YHFIGE0D/CmuXE74Uyaxm27RnrKUxEBl84V70GaIF4F5On8pSThxxizigXTRTKiczc+A5Zi29mid+1EFeUAJOa/DuHJfpVNY4pYEmhPl/Bk66L8kzlbJz6Hg/LIiJIRcy3UKrbSxPFIDpXn33drBHgklMDlrIVDZDXF6cn0Ml71SabB4A3TM6TK+oWZoyvftPIhcWhVwAWQj7nFNAiMEl1z/29ovHrRooqQFozf7GDW8Mjiu7ChZP9zx2H8JB/AAEFuWMwGV4AHICYdS9lOl/v+cDhgsnXdeuKEuxHhYlRxuRxJk/f17Sm/5H85UIzlu85wi3q/DW2FTZnlw4iJLnL6FArUIMzuBOZyoEhh0SPR41Xc4kkucDhnENybTZSR/yDzb0P1B7qjZ4GqcSEFja/hm/LH1oKJzZg8MEqeUoKYCUdVv9ek4IUGUONtVs53V5SOwFWR/nVuDk2BENr7NadYYVtu6MjBwgjso7NuhoNxVwIEP3BW67OQ8bxfNBtJJQNJejAhgZiqJItI9ucAfjQ== db48x@anglachel"
	& Apt.installed ["sudo"]
	& IABak.gitServer monsters
	& IABak.registrationServer monsters
	& IABak.graphiteServer
  where
	admins = map User ["joey", "db48x"]

       --'                        __|II|      ,.
     ----                      __|II|II|__   (  \_,/\
--'-------'\o/-'-.-'-.-'-.- __|II|II|II|II|___/   __/ -'-.-'-.-'-.-'-.-'-.-'-
-------------------------- |      [Docker]       / --------------------------
-------------------------- :                    / ---------------------------
--------------------------- \____, o          ,' ----------------------------
---------------------------- '--,___________,'  -----------------------------

-- Simple web server, publishing the outside host's /var/www
webserver :: Docker.Container
webserver = standardStableContainer "webserver"
	& Docker.publish "80:80"
	& Docker.volume "/var/www:/var/www"
	& Apt.serviceInstalledRunning "apache2"

-- My own openid provider. Uses php, so containerized for security
-- and administrative sanity.
openidProvider :: Docker.Container
openidProvider = standardStableContainer "openid-provider"
	& alias "openid.kitenet.net"
	& Docker.publish "8081:80"
	& OpenId.providerFor [User "joey", User "liw"]
		"openid.kitenet.net:8081"

-- Exhibit: kite's 90's website.
ancientKitenet :: Docker.Container
ancientKitenet = standardStableContainer "ancient-kitenet"
	& alias "ancient.kitenet.net"
	& Docker.publish "1994:80"
	& Apt.serviceInstalledRunning "apache2"
	& Git.cloned (User "root") "git://kitenet-net.branchable.com/" "/var/www"
		(Just "remotes/origin/old-kitenet.net")

oldusenetShellBox :: Docker.Container
oldusenetShellBox = standardStableContainer "oldusenet-shellbox"
	& alias "shell.olduse.net"
	& Docker.publish "4200:4200"
	& JoeySites.oldUseNetShellBox

-- for development of git-annex for android, using my git-annex work tree
gitAnnexAndroidDev :: Docker.Container
gitAnnexAndroidDev = GitAnnexBuilder.androidContainer dockerImage "android-git-annex" doNothing gitannexdir
	& Docker.volume ("/home/joey/src/git-annex:" ++ gitannexdir)
  where
	gitannexdir = GitAnnexBuilder.homedir </> "git-annex"
	
jerryPlay :: Docker.Container
jerryPlay = standardContainer "jerryplay" Unstable "amd64"
	& alias "jerryplay.kitenet.net"
	& Docker.publish "2202:22"
	& Docker.publish "8001:80"
	& Apt.installed ["ssh"]
	& User.hasSomePassword (User "root")
	& Ssh.permitRootLogin True
	
kiteShellBox :: Docker.Container
kiteShellBox = standardStableContainer "kiteshellbox"
	& JoeySites.kiteShellBox
	& Docker.publish "443:443"

type Motd = [String]

-- This is my standard system setup.
standardSystem :: HostName -> DebianSuite -> Architecture -> Motd -> Host
standardSystem hn suite arch motd = standardSystemUnhardened hn suite arch motd
	-- Harden the system, but only once root's authorized_keys
	-- is safely in place.
	& check (Ssh.hasAuthorizedKeys (User "root"))
		(Ssh.passwordAuthentication False)

standardSystemUnhardened :: HostName -> DebianSuite -> Architecture -> Motd -> Host
standardSystemUnhardened hn suite arch motd = host hn
	& os (System (Debian suite) arch)
	& Hostname.sane
	& Hostname.searchDomain
	& File.hasContent "/etc/motd" ("":motd++[""])
	& Apt.stdSourcesList `onChange` Apt.upgrade
	& Apt.cacheCleaned
	& Apt.installed ["etckeeper"]
	& Apt.installed ["ssh"]
	& GitHome.installedFor (User "root")
	& User.hasSomePassword (User "root")
	& User.accountFor (User "joey")
	& User.hasSomePassword (User "joey")
	& Sudo.enabledFor (User "joey")
	& GitHome.installedFor (User "joey")
	& Apt.installed ["vim", "screen", "less"]
	& Cron.runPropellor (Cron.Times "30 * * * *")
	-- I use postfix, or no MTA.
	& Apt.removed ["exim4", "exim4-daemon-light", "exim4-config", "exim4-base"]
		`onChange` Apt.autoRemove

standardStableContainer :: Docker.ContainerName -> Docker.Container
standardStableContainer name = standardContainer name (Stable "wheezy") "amd64"

-- This is my standard container setup, Featuring automatic upgrades.
standardContainer :: Docker.ContainerName -> DebianSuite -> Architecture -> Docker.Container
standardContainer name suite arch = Docker.container name (dockerImage system)
	& os system
	& Apt.stdSourcesList `onChange` Apt.upgrade
	& Apt.unattendedUpgrades
	& Apt.cacheCleaned
	& Docker.tweaked
  where
	system = System (Debian suite) arch

-- Docker images I prefer to use.
dockerImage :: System -> Docker.Image
dockerImage (System (Debian Unstable) arch) = "joeyh/debian-unstable-" ++ arch
dockerImage (System (Debian Testing) arch) = "joeyh/debian-unstable-" ++ arch
dockerImage (System (Debian (Stable _)) arch) = "joeyh/debian-stable-" ++ arch
dockerImage _ = "debian-stable-official" -- does not currently exist!

myDnsSecondary :: Property HasInfo
myDnsSecondary = propertyList "dns secondary for all my domains" $ props
	& Dns.secondary hosts "kitenet.net"
	& Dns.secondary hosts "joeyh.name"
	& Dns.secondary hosts "ikiwiki.info"
	& Dns.secondary hosts "olduse.net"

branchableSecondary :: RevertableProperty
branchableSecondary = Dns.secondaryFor ["branchable.com"] hosts "branchable.com"

-- Currently using kite (ns4) as primary with secondaries
-- elephant (ns3) and gandi.
-- kite handles all mail.
myDnsPrimary :: Bool -> Domain -> [(BindDomain, Record)] -> RevertableProperty
myDnsPrimary dnssec domain extras = (if dnssec then Dns.signedPrimary (Weekly Nothing) else Dns.primary) hosts domain
	(Dns.mkSOA "ns4.kitenet.net" 100) $
	[ (RootDomain, NS $ AbsDomain "ns4.kitenet.net")
	, (RootDomain, NS $ AbsDomain "ns3.kitenet.net")
	, (RootDomain, NS $ AbsDomain "ns6.gandi.net")
	, (RootDomain, MX 0 $ AbsDomain "kitenet.net")
	, (RootDomain, TXT "v=spf1 a a:kitenet.net ~all")
	, JoeySites.domainKey
	] ++ extras


monsters :: [Host]    -- Systems I don't manage with propellor,
monsters =            -- but do want to track their public keys etc.
	[ host "usw-s002.rsync.net"
		& Ssh.pubKey SshDsa "ssh-dss AAAAB3NzaC1kc3MAAAEBAI6ZsoW8a+Zl6NqUf9a4xXSMcV1akJHDEKKBzlI2YZo9gb9YoCf5p9oby8THUSgfh4kse7LJeY7Nb64NR6Y/X7I2/QzbE1HGGl5mMwB6LeUcJ74T3TQAlNEZkGt/MOIVLolJHk049hC09zLpkUDtX8K0t1yaCirC9SxDGLTCLEhvU9+vVdVrdQlKZ9wpLUNbdAzvbra+O/IVvExxDZ9WCHrnfNA8ddVZIGEWMqsoNgiuCxiXpi8qL+noghsSQNFTXwo7W2Vp9zj1JkCt3GtSz5IzEpARQaXEAWNEM0n1nJ686YUOhou64iRM8bPC1lp3QXvvZNgj3m+QHhIempx+de8AAAAVAKB5vUDaZOg14gRn7Bp81ja/ik+RAAABACPH/bPbW912x1NxNiikzGR6clLh+bLpIp8Qie3J7DwOr8oC1QOKjNDK+UgQ7mDQEgr4nGjNKSvpDi4c1QCw4sbLqQgx1y2VhT0SmUPHf5NQFldRQyR/jcevSSwOBxszz3aq9AwHiv9OWaO3XY18suXPouiuPTpIcZwc2BLDNHFnDURQeGEtmgqj6gZLIkTY0iw7q9Tj5FOyl4AkvEJC5B4CSzaWgey93Wqn1Imt7KI8+H9lApMKziVL1q+K7xAuNkGmx5YOSNlE6rKAPtsIPHZGxR7dch0GURv2jhh0NQYvBRn3ukCjuIO5gx56HLgilq59/o50zZ4NcT7iASF76TcAAAEAC6YxX7rrs8pp13W4YGiJHwFvIO1yXLGOdqu66JM0plO4J1ItV1AQcazOXLiliny3p2/W+wXZZKd5HIRt52YafCA8YNyMk/sF7JcTR4d4z9CfKaAxh0UpzKiAk+0j/Wu3iPoTOsyt7N0j1+dIyrFodY2sKKuBMT4TQ0yqQpbC+IDQv2i1IlZAPneYGfd5MIGygs2QMfaMQ1jWAKJvEO0vstZ7GB6nDAcg4in3ZiBHtomx3PL5w+zg48S4Ed69BiFXLZ1f6MnjpUOP75pD4MP6toS0rgK9b93xCrEQLgm4oD/7TCHHBo2xR7wwcsN2OddtwWsEM2QgOkt/jdCAoVCqwQ=="
	, host "github.com" 
		& Ssh.pubKey SshRsa "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ=="
	, host "gitlab.com"
		& Ssh.pubKey SshEcdsa "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBFSMqzJeV9rUzU4kWitGjeR4PWSa29SPqJ1fVkhtj3Hw9xjLVXVYrU9QlYWrOLXBpQ6KWjbjTDTdDkoohFzgbEY="
	, host "ns6.gandi.net"
		& ipv4 "217.70.177.40"
	, host "turtle.kitenet.net"
		& ipv4 "67.223.19.96"
		& ipv6 "2001:4978:f:2d9::2"
	, host "mouse.kitenet.net"
		& ipv6 "2001:4830:1600:492::2"
	, host "branchable.com"
		& ipv4 "66.228.46.55"
		& ipv6 "2600:3c03::f03c:91ff:fedf:c0e5"
		& alias "olduse.net"
		& alias "www.olduse.net"
		& alias "www.kitenet.net"
		& alias "joeyh.name"
		& alias "campaign.joeyh.name"
		& alias "ikiwiki.info"
		& alias "git.ikiwiki.info"
		& alias "l10n.ikiwiki.info"
		& alias "dist-bugs.kitenet.net"
		& alias "family.kitenet.net"
	, host "animx"
		& ipv4 "76.7.162.101"
		& ipv4 "76.7.162.186"
	]



                          --                                o
                          --             ___                 o              o
                       {-----\          / o \              ___o            o
                       {      \    __   \   /   _        (X___>--         __o
  _____________________{ ______\___  \__/ | \__/ \____                  |X__>
 <                                  \___//|\\___/\     \____________   _
  \                                  ___/ | \___    # #             \ (-)
   \    O      O      O             #     |     \ #                  >=)
    \______________________________# #   /       #__________________/ (-}


