from setuptools import setup, find_packages
import os
import ssi_lib

current_dir = os.path.abspath(os.path.dirname(__file__))
try:
    with open('requirements.txt', 'r') as f:
        install_requires = [_.strip() for _ in f.readlines()]
except FileNotFoundError:
    install_requires = []

with open('README.md', 'r') as f:
    long_description = f.read()


def main():
    setup(
        name=ssi_lib.__name__,
        version=ssi_lib.__version__,
        description=ssi_lib.__doc__.strip(),
        long_description=long_description,
        long_description_content_type='text/markdown',
        packages=find_packages(),
        project_urls={},
        author='GRENT S.A.',
        author_email='fmerg@grnet.gr',
        python_requires='>=3.10',
        install_requires=install_requires,
        zip_safe=False,
        keywords=[],
        classifiers=[
            'Development Status :: 4 - Beta',
            'Intended Audience :: Developers',
            'Programming Language :: Python :: 3.10',
            'Operating System :: POSIX',
            'Topic :: Security :: Cryptography',
            'Topic :: Software Development :: Libraries :: Python Modules',
            'License :: OSI Approved :: GNU General Public License v3 or later (GPLv3+)'
        ],
    )


if __name__ == '__main__':
    main()
