#!/usr/bin/env python
import sys
import os
import email.header
from glob import iglob

from mcarddb import CardHolder
from mcard import MCard
import vcard

_BASE="/home/beza1e1/dev/mycontacts/tests"
_USAGE="""\
Usage: %s <cmd> ...
where <cmd> is one of: search, show, merge, import-maildir
""" % sys.argv[0]

def do_search(args):
   query = " ".join(args)
   holder = CardHolder(_BASE, readonly=True)
   results = holder.search(query)
   for cid in results:
      card = holder.get(cid)
      name = card.get("name", None)
      if not name:
         name = card.get("email", "?")
      print cid, name

def do_show(args):
   holder = CardHolder(_BASE, readonly=True)
   print holder.get(args[0])

def do_merge(args):
   new_card = MCard()
   holder = CardHolder(_BASE)
   for cid in args:
      c = holder.get(cid)
      for k,v in list(c.items()):
         if new_card.get(k, None) != v:
            new_card[k] = v
      if new_card.text:
         new_card.text += "\n\n" + c.text
      else:
         new_card.text = c.text
   new_card.text = new_card.text.strip()
   new_cid = holder.put(new_card)
   print "new:", new_cid
   for cid in args:
      holder.delete(cid)

def _decode_name(string):
   parts = email.header.decode_header(string)
   name = ""
   for data, encoding in parts:
      if encoding:
         name += data.decode(encoding)
      else:
         name += data
   return unicode(name)

def _insert(name, addr, holder):
   if not addr: return
   found = holder.search(addr)
   for cid in found:
      card = holder.get(cid)
      if addr in card.getAll("email"):
         return # already in there
   card = MCard()
   if name:
      name = _decode_name(name)
      card["name"] = name
   card["email"] = addr
   holder.put(card)
   print "Added:", name, addr

def do_import_maildir(args):
   holder = CardHolder(_BASE)
   maildir = os.path.abspath(args[0])
   for p in iglob(maildir+"/*"):
      mail = email.message_from_file(open(p))
      fields = list()
      for f in ("From", "To", "Cc", "Bcc"):
         if mail[f]:
            fields.append(mail[f])
      addresses = email.utils.getaddresses(fields)
      for name,addr in addresses:
         _insert(name, addr, holder)

def do_import_vcf(args):
   vcfpath = args[0]
   holder = CardHolder(_BASE)
   for vc in vcard.read_file(vcfpath):
      mc = vcard.vcard2mcard(vc)
      for adr in mc.getAll("email"):
         results = list(holder.search(adr))
         if results:
            print "already!", adr, results
      holder.put(mc)

def main(args):
   cmd = args.pop(0)
   cmd = cmd.replace("-", "_")
   try:
      func = globals()["do_"+cmd]
   except KeyError:
      print _USAGE
      return
   func(args)


if __name__ == "__main__":
   main(sys.argv[1:])
