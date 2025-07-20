Notes from testing alto samples in tests/alto_samples

## 3410938

```
./merge.rb tests/alto_samples/34109381_plaintext.txt tests/alto_samples/34109381_alto.xml
```

### Missing element in ground truth

In this case, the plaintext file is missing a name between Fanny and 
Luisa -- the ALTO flie records "Matilda", which is visible in 
34109381_image.jpg between "Fanny" and "Luisa".  Obviously this is not 
aligned, but I'm not sure what to do in this case -- the ground truth is 
not correct, so the extra word in the ALTO should probably be removed?

### Missing alignment in 17

The final word of the list is 17, though there is also punctuation in 
the plaintext.  Why isn't 17 aligned in the first pass?

## 34111603

Transcription has substantial tabular mark-up; results are terrible

## 34126288

### Spot problems -- why isn't State of North Carlolina being resolved?

Plaintext:
```
uary the year of our Lord One thousand Eight hundred and Twe-
nty and between William Leathers of the county of Orange & State
of North carolina of the one part and James Leathers of the county
```

ALTO:
```
uary _ in the year of our Lord One thousand Eight hundred and Twe 
=nty two by and between William Leathers of the county of Orange & State 
of Northcarolina of the one part and James Lealbers 
of the county 
```

Final alignment:
```
uary ___ ___ the year of our Lord One thousand Eight hundred and Twe- 
nty and ___ ___ between William Leathers of the county of Orange & State 
___ ___ ___ the one part and James Leathers 
```

Notes during span matching in Phace C:
```
4	A	of Northcarolina of
	C	of North carolina of

Unequal alignment 4::3:
of North carolina of
into
of Northcarolina of
```


### Final alignments missing
The last passages are totally unaligned -- why?

Plaintext:
```
this indenture and all and Every thing therein Contained shall cease determine
and become void But if the said William Leathers his heirs &c shall
fail to pay or cause to be paid to the said Cain & Bennehan
heirs or assigns the aforesaid Sum of Money with such interest as may accrue
```

ALTO contents:
```
this Indenture and all and Every thing therein Contained shall Cease determined 
and become void _ But if the said William Leathers his heirs &c - shall 
fait to pay on cause to be paid to the said Coin & Dennehan 
hein or assign the 
afforsaid sum of money with such intent as may accrue 
```


Final alignment:
```
this indenture and all and Every thing therein Contained shall cease determine 
and become void ___ But ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ 
___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ 
___ ___ ___ ___ 
___ ___ ___ ___ ___ ___ ___ ___ ___ ___ 

```

Why isn't `accrue` aligned in the initial pass?




## 34232508

## Missing alingment at the beginning of the text
The plaintext has "To\nMr" while the ALTO has "Mr" at the beginning.  Why don't these align?

Plaintext:
```
To
Mr Richard Bennehan
```

ALTO:
```
Mr Richard Bennehan 
```

Final Alignment:
```
___ Richard Bennehan 
```

(Note that this may be related to the indenture problem above, in which 
the final passages were totally unaligned.

## 34232563
No issues -- no correction needed; all HTR words matched plaintext.

## 34232659
### Final span is not aligned
The last two words in the final span are not aligned, even though the 
word counts match and there is one perfect match on the word "not"

Plaintext:
```
Mrs Meadows that you want brot
home & how you want your pice of
Flan cloth woven as I may not find
```

ALTO:
```
Mrs Meadows that you want brat 
home & how you want your fice of 
Ilan cloth woom as I may not fut 

```

Final alignment:
```
Mrs Meadows that you want brot 
home & how you want your pice of 
Flan cloth woven as I may ___ ___ 

```


## 34232712
### Final span not aligned
The last three words in the text are not aligned, even though they are 
identical in the plaintext and alto

Plaintext:
```
the cotton I wrote to you a bout as being
in Demopolis is still thare - I would
```

ALTO:
```
the Cotton I wrote to gou a bout as being 
in Demopolis is still thare - I would 
```

Final alignment:
```
the cotton I wrote to you a bout as being 
in Demopolis is still thare ___ ___ ___ 
```

### Long span not aligned on fourth line
Plaintext:
```
May 2nd 1866
Mr P.C. Cameron
Dear Sir this
will inform you we are all tolerable well with
the exceptions of my wife who has bin very
```

ALTO:
```
May 20d 1866 
Mr P.C. Cameron 
Dear Sir this 
well inform you we are all toterable well with 
the excetions of my wife who has bin very 
```

Final alginment:
```
May 2nd 1866 
Mr P.C. Cameron 
Dear Sir this 
well inform ___ ___ ___ ___ ___ ___ with 
the exceptions of my wife who has bin very 
```

### Mismatched word count spans not aligned


Plaintext:
```
a long the best I can with the crop  we are
hindered a great deal by the constant rain
I never saw such rains fall from the heavens
that we are having every week.  have not
bin able to work more than three days in a
week for the last 3 weeks. the cotton
```

ALTO:
```
a long the best I can with the crop - we are 
nendered a greatlal by the constant rain 
I never saw such rains fall from the heavens 
that we are having every welk - have not 
fin able to work more than three days in a 
```


Final alignment:
```
a long the best I can with the crop ___ we are 
hindered a ___ by the constant rain 
I never saw such rains fall from the heavens 
that we are having every week. ___ have not 
bin able to work more than three days in a 
week for the last 3 weeks. ___ the cotton 
```

#### Notes on specific issues
##### crop ___ we
Merging ` ` into ` - ` the problem here might be the plaintext export, 
if we're not converting an emdash into a `-`.  TODO: check FromThePage 
plaintext export logic

##### a ___ by
Merging `great deal` into `greatlal`

##### week. ___ have
Merging `week.  have` into `welk - have`.  In the ALTO HTR, we have a 
separate dash, while the plaintext has a period attached to the final 
word of the sentence.  We should be able to simply delete this.


##### weeks. ___ the
Same as previous.

# 34232713
## Jumbled line order in ALTO leads to lack of alignment
Plaintext:
```
the men pretty much all keep their wifes
in the house. though they feed them
at ther expence.  I have to
```

ALTO
```the men pretty much all keep their wifes 
though they feed them 
in the house 
Ishave to 
atther expence 
```

Final alignment:
```
the men pretty much all keep their wifes 
though they feed ___ 
___ ___ ___ 
___ ___ 
___ ___ 
```

(There is a chance that this may be fixed by the fix for the final span, 
so we should re-test this file after fixing that bug.)


# 985545
Command `./merge.rb tests/alto_samples/985545_plaintext.txt tests/alto_samples/985545_alto.xml 
` throws an exception when run:

```
./merge.rb:246:in `block (2 levels) in <main>': undefined method `[]' for nil (NoMethodError)

        if best_match[1] < LEVENSHTEIN_THRESHOLD
                     ^^^
	from ./merge.rb:241:in `each'
	from ./merge.rb:241:in `block in <main>'
	from ./merge.rb:222:in `each'
	from ./merge.rb:222:in `each_with_index'
	from ./merge.rb:222:in `<main>'
```

# 985580
Command throws this exception when run:
```
./merge.rb:313:in `block (2 levels) in <main>': undefined method `[]' for nil (NoMethodError)

                @alignment_map[corrected_index] = alto_range[range_index][:element]
                                                                         ^^^^^^^^^^
	from ./merge.rb:307:in `each'
	from ./merge.rb:307:in `each_with_index'
	from ./merge.rb:307:in `block in <main>'
	from ./merge.rb:267:in `each'
	from ./merge.rb:267:in `each_with_index'
	from ./merge.rb:267:in `<main>'
```

# 985661

