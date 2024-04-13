# domoticz-victron
Set of scripts for ESS Node Red and domoticz dzvents to control your DIY Victron home battery through domoticz

Many people have started to build home batteries using Victron technologies like Multiplus II, Cerbo and so on
Most external (commercial) software as well as Victron's own Dynamic ESS don't allow the granular control that I needed
to most optimally use my battery as most of these systems try to learn your regular behaviour BUT, with 2 electric cars
the behaviour is so unpredictable that this just won't work

Since I already use domoticz for over a decade, it knows about all my maing consumers and therefore has a much better
ability to control what my barrey should do at any time.

These scrips will ultimately provide a full repo of everything required on the ESS side (using Node Red) and the domoticz side

ATM VERY MUCH WIP since there will be scripts from multiple contributors (heggink being full 3 phase battery, gizmocuz being 1 phase, ..) that may not be completely in sync. 
Hopefully, that will happen soon.

Key actions:
1) parameterise instead of hard code the number of phases
2) paramererise the time to fully load (hardcoded 3 hrs)
3) parameterise all access variables (domoticz IP and security, ess IP and security, mqtt ip and security, topics) from all ends
4) sync up scripts between multiple sub repos (giz, myself)
5) switch from domo variables to timers for (the setpoints and) battmodes in the lua scripts
6)  ...
