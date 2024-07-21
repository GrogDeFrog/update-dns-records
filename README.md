# Instructions
The script, `update-dns-records`, matches the records in `active-records.json`
to records within Cloudflare, then updates the IPs stored in each record with
the machine's IP.  

The matching process works like this:  

1. Open `active-records.json`  
2. For each label, find an API key at `api-keys/label`. This label is never sent
   to Cloudflare! It is client-side only.  
3. For each label, get the value of the `"name"` element and search for a
   Cloudflare DNS zone ID that matches that name. Only zones accessible to the
   API key corresponding with this zone's client-side label will be searched.  
4. Get every record from Cloudflare within the zone matching that ID.  
5. For each element of `"records"` (in `active-records.json`), there are a set
   of keys and values. Comb through the records from Cloudflare for those whose
   values match every key on record locally. Try to make these uniquely
   identifying because if you don't I think the program's not going to work.  
6. Send a request to the Cloudflare API to update each matching header with the
   current IP.  

Run `./update-dns-records` with the flag `-s` or `--silent` to supress output.  
