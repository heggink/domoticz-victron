#!/usr/bin/python3

#
# this script summarises all usage and delivery data in domoticz to produce a summed usage/delivery
# as well as the associated cost given hourly rates
# it needs to be parameterised
#
import requests
import sys
import urllib.parse
from datetime import date
from datetime import timedelta

# Define the URL of the website that returns a JSON response
#usage L1 device
u1_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=5192&range=day"
#usage L2 device
u2_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=5193&range=day"
#usage L3 device
u3_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=5194&range=day"
# delivery L1 device
d1_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=5226&range=day"
# delivery L2 device
d2_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=5290&range=day"
# delivery L3 device
d3_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=9358&range=day"
# hourly prices device
r_url = "http://freenas:18081/json.htm?type=command&param=graph&sensor=counter&idx=9367&range=day"

# Make a GET request to the URL and store the response object
u1_response = requests.get(u1_url)
u2_response = requests.get(u2_url)
u3_response = requests.get(u3_url)
d1_response = requests.get(d1_url)
d2_response = requests.get(d2_url)
d3_response = requests.get(d3_url)
r_response = requests.get(r_url)

if len(sys.argv) == 1:
    delta=1
else:
    delta=int(sys.argv[1])

#print('I have delta ', delta)
today = date.today()
yesterday = today - timedelta(days = delta)
y_str = yesterday.strftime("%Y-%m-%d")
usage_l1 = []
usage_l2 = []
usage_l3 = []
delivery_l1 = []
delivery_l2 = []
delivery_l3 = []
rates = []
cost = []


def fill_data(response, array):
    data = response.json()
    num_items = len(data["result"])
    i=0
    use=0
    while i < num_items:
        if data["result"][i]["d"][0:10] == y_str:
            array.append(float(data["result"][i]["v"]))
            array.append(float(data["result"][i+1]["v"]))
            array.append(float(data["result"][i+2]["v"]))
            array.append(float(data["result"][i+3]["v"]))
            array.append(float(data["result"][i+4]["v"]))
            array.append(float(data["result"][i+5]["v"]))
            array.append(float(data["result"][i+6]["v"]))
            array.append(float(data["result"][i+7]["v"]))
            array.append(float(data["result"][i+8]["v"]))
            array.append(float(data["result"][i+9]["v"]))
            array.append(float(data["result"][i+10]["v"]))
            array.append(float(data["result"][i+11]["v"]))
            array.append(float(data["result"][i+12]["v"]))
            array.append(float(data["result"][i+13]["v"]))
            array.append(float(data["result"][i+14]["v"]))
            array.append(float(data["result"][i+15]["v"]))
            array.append(float(data["result"][i+16]["v"]))
            array.append(float(data["result"][i+17]["v"]))
            array.append(float(data["result"][i+18]["v"]))
            array.append(float(data["result"][i+19]["v"]))
            array.append(float(data["result"][i+20]["v"]))
            array.append(float(data["result"][i+21]["v"]))
            array.append(float(data["result"][i+22]["v"]))
            array.append(float(data["result"][i+23]["v"]))
            break
        else:
            i=i+1

if u1_response.status_code == 200 and \
   u2_response.status_code == 200 and \
   u3_response.status_code == 200 and \
   d1_response.status_code == 200 and \
   d2_response.status_code == 200 and \
   d3_response.status_code == 200 and \
   r_response.status_code == 200:
    fill_data(u1_response, usage_l1)
    fill_data(u2_response, usage_l2)
    fill_data(u3_response, usage_l3)
    fill_data(d1_response, delivery_l1)
    fill_data(d2_response, delivery_l2)
    fill_data(d3_response, delivery_l3)

    data = r_response.json()
    num_items = len(data["result"])
    i=0
    while i < num_items:
        if data["result"][i]["d"][0:10] == y_str:
            rates.append(data["result"][i]["v"])
            i=i+1
        else:
            i=i+1

    total=0
    energy_total=0
    for i in range(24):
        usage_tot = float(usage_l1[i]) + float(usage_l2[i]) + float(usage_l3[i])
        #print( float(usage_l1[i]) , float(usage_l2[i]) , float(usage_l3[i]))
        #print('Total usage is ', usage_tot, ' for date ',y_str)
        delivery_tot = float(delivery_l1[i]) + float(delivery_l2[i]) + float(delivery_l3[i])
        #print('Total delivery is ', delivery_tot, ' for date ',y_str)
        #print('Rate is ',rates[i])
        energy_tot=usage_tot-delivery_tot
        hr_cost=round((energy_tot) * float(rates[i])/1000,2)
        total=total+hr_cost
        energy_total=energy_total+hr_cost
        cost.append(hr_cost)
        print('I came to a cost of ', hr_cost, ' for hr ',i)
        # total cost device
        call_url="http://freenas:18081/json.htm?type=command&param=udevice&idx=9507&nvalue=0&svalue=-1;"+str(hr_cost*100)+";"+y_str+"%20"+str(i).zfill(2)+":00:00"
        resp = requests.get(call_url)
        # total energy device
        call_url="http://freenas:18081/json.htm?type=command&param=udevice&idx=9560&nvalue=0&svalue=-1;"+str(energy_tot)+";"+y_str+"%20"+str(i).zfill(2)+":00:00"
        resp = requests.get(call_url)
        #print(call_url)

    print('\nTotal for date ', y_str, ' is ', round(total,2))
    total=total*100
    call_url="http://freenas:18081/json.htm?type=command&param=udevice&idx=9507&nvalue=0&svalue=-1;"+str(round(total,2))+";"+y_str
    resp = requests.get(call_url)
    call_url="http://freenas:18081/json.htm?type=command&param=udevice&idx=9560&nvalue=0&svalue=-1;"+str(energy_total*1000)+";"+y_str
    resp = requests.get(call_url)

else:
    print('Something went wrong calling domo')

