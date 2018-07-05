#!/usr/bin/env python3
import yaml
import argparse

DEMO_DOMAIN = 'oregon-b.moz.works'


def service_name_port(service_filename):
    with open(service_filename) as f:
        service = yaml.load(f)
    return (service['metadata']['name'], service['spec']['ports'][0]['port'])


def add_service(ingress_filename, service_name, service_port, demo_domain):
    with open(ingress_filename) as f:
        raw_yaml = f.read()
        if 'serviceName: {}'.format(service_name) in raw_yaml:
            print('ingress already exists for {}'.format(service_name))
            return
        else:
            ingress = yaml.load(raw_yaml)
    print('adding {} to {}'.format(service_name, ingress['metadata']['name']))
    host = '.'.join([service_name, demo_domain])
    ingress['spec']['rules'].append(
        {'host': host,
         'http': {'paths':
                  [{'backend':
                    {'serviceName': service_name,
                     'servicePort': service_port}}]}})
    with open(ingress_filename, 'w') as f:
        yaml.dump(ingress, f, default_flow_style=False)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('service_filename')
    parser.add_argument('ingress_filename')
    parser.add_argument('demo_domain')
    args = parser.parse_args()
    service_name, service_port = service_name_port(args.service_filename)
    add_service(args.ingress_filename, service_name, service_port, args.demo_domain)


if __name__ == '__main__':
    main()
