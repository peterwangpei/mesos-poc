#!/usr/bin/env python
import sys
from optparse import OptionParser


def main(argv):
    parser = OptionParser(usage="%prog -c config")
    parser.add_option("-c", "--config", dest="config", help="The environment config file")

    (options, argv) = parser.parse_args(argv)

    if options.case is None:
        parser.error("The environment config file was not given")




if __name__ == "__main__":
    main(sys.argv)