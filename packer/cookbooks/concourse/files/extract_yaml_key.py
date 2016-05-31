#!/usr/bin/env python3

import argparse
import sys
import unittest
import yaml

class TestStringMethods(unittest.TestCase):
  
  TEST_YAML_GOOD = """
  foo: bar
  baz: bork
  """

  TEST_YAML_BLANK = ''
  
  TEST_NOT_YAML = """
  <html>
  <body>
  <h1>This is not yaml</h1>
  </body>
  </html>
  """

  def test_extract_good(self):
    """A value can be extracted from valid yaml"""
    assert extract_key(self.TEST_YAML_GOOD, 'foo') == 'bar'

  def test_extract_missing(self):
    """A default is returned if the key is not found in valid yaml"""
    assert extract_key(self.TEST_YAML_GOOD, 'bar', 'hello') == 'hello'

  def test_extract_blank(self):
    """A default is returned if blank is provided"""
    assert extract_key(self.TEST_YAML_BLANK, 'bar', 'hello') == 'hello'

  def test_extract_bad(self):
    """A default is returned if blank is provided"""
    assert extract_key(self.TEST_NOT_YAML, 'bar', 'hello') == 'hello'
  

def extract_key(content, kk, default=None):
  """Extract a top level key from content and return it's value
  
  Args:
    content(str): A YAML document
    kk(str): The top level key to retrieve the value for
    default: The value to return if the key doesn't exist or the content cannot be parsed
    
  Returns:
    The value of the key, or default
  
  """

  try:
    y = yaml.load(content)
    return y.get(kk, default)
  except:
    return default


if __name__ == "__main__":
  
  parser = argparse.ArgumentParser(description='Extract a value from a yaml document')
  parser.add_argument('key', help='The key of the value to extract')
  parser.add_argument('default', default='', nargs='?', help='A default value to return if the key does not exist')  
  
  args = parser.parse_args()

  sys.stdout.write(
    extract_key(sys.stdin.read(), args.key, args.default)
  )
