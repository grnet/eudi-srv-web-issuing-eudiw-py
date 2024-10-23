"""Library providing SSI capabilities"""

from .ssi import \
    SSI, \
    SSIGenerationError, \
    SSIRegistrationError, \
    SSIResolutionError, \
    SSIIssuanceError, \
    SSIVerificationError, \
    Template, \
    Vc

__version__ = '0.1.0'

__all__ = (
    'SSI',
    'SSIGenerationError',
    'SSIRegistrationError',
    'SSIResolutionError',
    'SSIIssuanceError',
    'SSIVerificationError',
    'Template',
    'Vc',
)
