"""
Disposable email domain checker.
Blocks temporary/throwaway email services from signing up for free trials.
"""

# Top ~200 most common disposable email domains
DISPOSABLE_DOMAINS = {
    "10minutemail.com", "guerrillamail.com", "guerrillamail.net", "mailinator.com",
    "tempmail.com", "throwaway.email", "temp-mail.org", "fakeinbox.com",
    "sharklasers.com", "guerrillamailblock.com", "grr.la", "guerrillamail.info",
    "guerrillamail.biz", "guerrillamail.de", "guerrillamail.org", "dispostable.com",
    "yopmail.com", "yopmail.fr", "cool.fr.nf", "jetable.fr.nf", "nospam.ze.tc",
    "nomail.xl.cx", "mega.zik.dj", "speed.1s.fr", "courriel.fr.nf", "moncourrier.fr.nf",
    "trashmail.com", "trashmail.me", "trashmail.net", "trashmail.org",
    "mailnesia.com", "maildrop.cc", "discard.email", "discardmail.com",
    "mailcatch.com", "tempail.com", "tempr.email", "temp-mail.io",
    "mohmal.com", "burnermail.io", "inboxkitten.com", "getairmail.com",
    "mailexpire.com", "tempinbox.com", "tempmailaddress.com", "emailondeck.com",
    "getnada.com", "tmpmail.net", "tmpmail.org", "boun.cr", "bouncr.com",
    "mailsac.com", "harakirimail.com", "tmail.ws", "mailtemp.info",
    "throwam.com", "33mail.com", "mailtothis.com", "mintemail.com",
    "spamgourmet.com", "mytemp.email", "tempmailo.com", "emailfake.com",
    "crazymailing.com", "armyspy.com", "cuvox.de", "dayrep.com", "einrot.com",
    "fleckens.hu", "gustr.com", "jourrapide.com", "rhyta.com", "superrito.com",
    "teleworm.us", "mailnator.com", "maildrop.cc", "anonbox.net",
    "mytrashmail.com", "mt2015.com", "thankyou2010.com", "trash-mail.com",
    "trashymail.com", "trashymail.net", "wegwerfmail.de", "wegwerfmail.net",
    "wegwerfmail.org", "wh4f.org", "meltmail.com", "spaml.com",
    "uggsrock.com", "mailzilla.com", "spamfree24.org", "spamfree.eu",
    "safetymail.info", "filzmail.com", "mailmoat.com", "spambox.us",
    "trashmail.at", "objectmail.com", "proxymail.eu", "rcpt.at",
    "trash-mail.at", "trashmail.io", "wegwerfmail.de", "sogetthis.com",
    "mailinater.com", "trbvm.com", "mailforspam.com", "safetypost.de",
    "notmailinator.com", "veryreallydumb.com", "kurzepost.de", "emailigo.de",
    "spam4.me", "trash2009.com", "binkmail.com", "bobmail.info",
    "chammy.info", "devnullmail.com", "dfgh.net", "dingbone.com",
    "fudgerub.com", "gishpuppy.com", "hulapla.de", "haltospam.com",
    "imstations.com", "kasmail.com", "koszmail.pl", "mailblocks.com",
    "mailquack.com", "mezimages.net", "noclickemail.com",
    "pookmail.com", "recode.me", "regbypass.com", "rejectmail.com",
    "rklips.com", "rmqkr.net", "royal.net", "s0ny.net",
    "safersignup.de", "saynotospams.com", "skeefmail.com", "slaskpost.se",
    "slipry.net", "spamherelots.com", "spamhereplease.com",
    "tempomail.fr", "temporaryemail.net", "temporaryemail.us",
    "temporaryforwarding.com", "temporaryinbox.com", "temporarymailaddress.com",
    "thanksnospam.info", "thisisnotmyrealemail.com", "throwawayemailaddress.com",
    "tittbit.in", "tradermail.info", "turual.com", "twinmail.de",
    "tyldd.com", "uggsrock.com", "upliftnow.com", "venompen.com",
    "veryreallydumb.com", "viditag.com", "viewcastmedia.com",
    "walkmail.net", "webemail.me", "wilemail.com", "willhackforfood.biz",
    "willselfdestruct.com", "winemaven.info", "wronghead.com",
    "wuzup.net", "wuzupmail.net", "wwwnew.eu", "xagloo.com",
    "xemaps.com", "xents.com", "xjoi.com", "xoxy.net",
    "yapped.net", "yep.it", "yogamaven.com", "zippymail.info",
    "zoemail.org", "guerrillamail.com",
}


def is_disposable_email(email: str) -> bool:
    """Check if an email address uses a known disposable/temporary domain."""
    if not email or "@" not in email:
        return False
    domain = email.rsplit("@", 1)[1].lower().strip()
    return domain in DISPOSABLE_DOMAINS


def validate_email_for_trial(email: str) -> tuple[bool, str]:
    """Validate an email for trial signup. Returns (is_valid, error_message)."""
    if not email or "@" not in email:
        return False, "Email non valida"

    # Basic format check
    parts = email.split("@")
    if len(parts) != 2 or "." not in parts[1]:
        return False, "Email non valida"

    # Disposable check
    if is_disposable_email(email):
        return False, "Le email temporanee non sono ammesse. Usa un'email personale."

    return True, ""
