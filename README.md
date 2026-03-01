# domoticz-victron
Set of scripts for ESS Node Red and domoticz dzvents to control your DIY Victron home battery through domoticz

Many people have started to build home batteries using Victron technologies like Multiplus II, Cerbo and so on
Most external (commercial) software as well as Victron's own Dynamic ESS don't allow the granular control that I needed
to most optimally use my battery as most of these systems try to learn your regular behaviour BUT, with 2 electric cars
the behaviour is so unpredictable that this just won't work

Since I already use domoticz for over a decade, it knows about all my maing consumers and therefore has a much better
ability to control what my barrey should do at any time.

These scrips will ultimately provide a full repo of everything required on the ESS side (using Node Red) and the domoticz side

--- MAJOR UPDATE ---
Since the latest releaes, all control has been implemented in Node Red. The only domoticz (lua) script is for displaying the battery schedule in domoticz.
Node red creates all necessary devices and variables though MQTT-AD
With that, the battery is now a fully self contained system even with its own dashboard to control it.
